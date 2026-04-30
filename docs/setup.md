# Setup Guide

This guide provides step-by-step instructions to set up the private Azure AKS infrastructure.

## Prerequisites

### Required Tools

- **Azure CLI** (v2.50+)
  ```bash
  az --version
  ```

- **Terraform** (v1.5+)
  ```bash
  terraform --version
  ```

- **kubectl**
  ```bash
  kubectl version --client
  ```

- **Helm** (v3.12+)
  ```bash
  helm version
  ```

- **Git**
  ```bash
  git --version
  ```

### Azure Permissions

You need the following Azure permissions:
- Owner or Contributor on the subscription
- Azure AD permissions to create App Registrations and Service Principals
- Permissions to create Azure DevOps service connections

## Step 1: Azure Authentication

### Login to Azure

```bash
az login
az account set --subscription <your-subscription-id>
```

### Create Service Principal for Terraform

```bash
# Create service principal
SP_NAME="terraform-sp-${RANDOM}"
az ad sp create-for-rbac \
  --name $SP_NAME \
  --role "Contributor" \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth > terraform-creds.json

# Note the appId (client ID) and password (client secret)
# You'll need these for Terraform configuration
```

### Create Service Principal for Azure DevOps

```bash
# Create service principal for CI/CD
DEVOPS_SP_NAME="devops-sp-${RANDOM}"
az ad sp create-for-rbac \
  --name $DEVOPS_SP_NAME \
  --role "AcrPush" \
  --scopes /subscriptions/<your-subscription-id>/resourceGroups/<resource-group-name> \
  --years 2

# Note the object ID and client ID
# You'll need these for Azure DevOps service connection
```

## Step 2: Configure Terraform

### Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### Create `terraform.tfvars`

Create a `terraform.tfvars` file with your specific values:

```hcl
# Admin CIDR blocks (your IP addresses for SSH access)
admin_cidr_blocks = [
  "YOUR_IP_ADDRESS/32"
]

# Azure AD Group Object IDs for cluster admin access
# Create a group in Azure AD and add your users
admin_group_object_ids = [
  "YOUR_AZURE_AD_GROUP_OBJECT_ID"
]

# Azure DevOps Service Principal Object ID
devops_service_principal_id = "YOUR_DEVOPS_SP_OBJECT_ID"

# Terraform Service Principal Object ID (for Key Vault access during deployment)
terraform_sp_object_id = "YOUR_TERRAFORM_SP_OBJECT_ID"
```

### Validate Terraform Configuration

```bash
terraform validate
terraform plan -out=tfplan
```

## Step 3: Deploy Infrastructure

### Apply Terraform

```bash
terraform apply tfplan
```

This will create:
- Virtual Network with subnets
- Private DNS zones
- Azure Container Registry (ACR) with private endpoint
- Azure Key Vault with private endpoint
- Private AKS cluster
- Log Analytics Workspace

### Retrieve Outputs

```bash
terraform output -json > outputs.json
```

Key outputs to note:
- `aks_name`
- `acr_login_server`
- `key_vault_name`
- `key_vault_uri`
- `workload_identity_client_ids`

## Step 4: Configure kubectl

### Get AKS Credentials

```bash
# For private clusters, you need to access from within the VNet
# Use a jumpbox or VPN connection

az aks get-credentials \
  --name $(terraform output -raw aks_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### Verify Cluster Access

```bash
kubectl get nodes
kubectl get pods -A
```

## Step 5: Install ArgoCD

### Add ArgoCD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Install ArgoCD

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values ../helm-charts/argocd/values.yaml \
  --set server.service.type=LoadBalancer
```

### Access ArgoCD UI

```bash
# Port-forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
argocd admin initial-password -n argocd
```

Navigate to `https://localhost:8080` and login with `admin` and the retrieved password.

### Configure ArgoCD Repository

In the ArgoCD UI:
1. Go to Settings → Repositories
2. Connect your GitOps repository
3. Use SSH or HTTPS with credentials

## Step 6: Deploy ArgoCD Applications

### Create GitOps Repository Structure

```bash
# In your GitOps repository
mkdir -p apps/production/sample-app
```

### Copy Application Manifests

Copy the ArgoCD application manifests from this project:

```bash
cp argocd-apps/blue-green/application.yaml <gitops-repo>/apps/production/sample-app/
cp argocd-apps/blue-green/values.yaml <gitops-repo>/apps/production/sample-app/
```

### Commit and Push

```bash
cd <gitops-repo>
git add .
git commit -m "Add sample-app ArgoCD application"
git push origin main
```

### Sync Application in ArgoCD

In the ArgoCD UI:
1. The application should appear in the list
2. Click "Sync" to deploy the application
3. Monitor the sync status

## Step 7: Configure Azure DevOps

### Create Service Connection

1. Go to Azure DevOps → Project Settings → Service Connections
2. Create a new service connection
3. Select "Azure Resource Manager"
4. Choose "Service principal (automatic)" or "Workload Identity Federation"
5. Configure with your subscription and service principal

### Create Variable Group

Create a variable group with the following variables:

| Variable | Value | Description |
|----------|-------|-------------|
| ACR_NAME | `$(terraform output -raw acr_name)` | ACR name |
| ACR_LOGIN_SERVER | `$(terraform output -raw acr_login_server)` | ACR login server |
| AKS_NAME | `$(terraform output -raw aks_name)` | AKS cluster name |
| AKS_RESOURCE_GROUP | `$(terraform output -raw resource_group_name)` | Resource group name |
| KEYVAULT_NAME | `$(terraform output -raw key_vault_name)` | Key Vault name |
| AZURE_TENANT_ID | Your tenant ID | Azure AD tenant ID |
| WORKLOAD_IDENTITY_CLIENT_ID | Sample app workload identity client ID | From Terraform output |

### Import Pipelines

1. Go to Pipelines → Create Pipeline
2. Select "Existing Azure Pipeline YAML"
3. Point to `pipelines/ci-build.yml`
4. Configure triggers and variables
5. Repeat for `pipelines/cd-deploy.yml`

## Step 8: Configure Key Vault Secrets

### Add Secrets to Key Vault

```bash
# Set database connection string
az keyvault secret set \
  --vault-name $(terraform output -raw key_vault_name) \
  --name database-connection-string \
  --value "Server=myserver;Database=mydb;User=myuser;Password=mypassword;"

# Set API key
az keyvault secret set \
  --vault-name $(terraform output -raw key_vault_name) \
  --name api-key \
  --value "your-api-key-here"
```

### Verify Secret Access

```bash
# List secrets
az keyvault secret list --vault-name $(terraform output -raw key_vault_name)
```

## Step 9: Build and Deploy Application

### Create Sample Application

Create a simple application or use the provided sample:

```dockerfile
# Dockerfile example
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "SampleApp.dll"]
```

### Trigger CI Pipeline

1. Push code changes to the repository
2. The CI pipeline will trigger automatically
3. Monitor the build in Azure DevOps

### Trigger CD Pipeline

1. After CI completes, manually trigger the CD pipeline
2. The pipeline will update the GitOps repository
3. ArgoCD will sync and deploy the application

## Step 10: Verify Deployment

### Check Application Status

```bash
# Check pods
kubectl get pods -n production -l app=sample-app

# Check service
kubectl get svc sample-app -n production

# Check logs
kubectl logs -n production -l app=sample-app,color=blue
```

### Access Application

```bash
# Port-forward to test
kubectl port-forward svc/sample-app -n production 8080:80

# Test health endpoint
curl http://localhost:8080/health/ready
```

## Step 11: Blue-Green Deployment

### Deploy New Version

1. Make code changes
2. Push to repository
3. CI builds new image
4. CD updates GitOps with new version
5. ArgoCD deploys to inactive color (green if blue is active)

### Switch Traffic

```bash
# Use the deployment script
./scripts/deploy.sh switch-color production sample-app green

# Or manually update Helm values
helm upgrade sample-app ./helm-charts/sample-app \
  --namespace production \
  --reuse-values \
  --set deployment.activeColor=green
```

### Rollback

```bash
# Quick rollback using script
./scripts/deploy.sh rollback production sample-app
```

## Troubleshooting

### Cannot Access Private AKS

- Ensure you're connected to the VNet via VPN or jumpbox
- Verify private DNS zones are correctly configured
- Check that the AKS API server subnet has proper connectivity

### ACR Pull Failures

- Verify ACR private endpoint is connected
- Check that AKS kubelet identity has AcrPull role
- Ensure private DNS zone for ACR is linked to VNet

### Key Vault Access Issues

- Verify workload identity federation is configured
- Check that the service account has the correct annotation
- Ensure the federated credential subject matches the service account

### ArgoCD Sync Failures

- Check ArgoCD repository connection
- Verify Helm chart values are valid
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

## Next Steps

- Set up monitoring (Prometheus, Grafana)
- Configure logging (Loki, Fluent Bit)
- Implement network policies
- Set up automated testing
- Configure backup and disaster recovery
- Implement cost monitoring and optimization
