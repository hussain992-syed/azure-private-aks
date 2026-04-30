# Quick Deployment Guide

This is a condensed guide for quickly deploying the private Azure AKS infrastructure.

## Prerequisites Checklist

- [ ] Azure CLI installed and authenticated
- [ ] Terraform installed
- [ ] kubectl installed
- [ ] Helm installed
- [ ] Azure subscription with Owner/Contributor access
- [ ] Azure DevOps organization (for CI/CD)

## Step 1: Configure Terraform (5 minutes)

```bash
cd terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# - admin_cidr_blocks (your public IP)
# - admin_group_object_ids (Azure AD group)
# - devops_service_principal_id
# - terraform_sp_object_id
```

## Step 2: Deploy Infrastructure (20-30 minutes)

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Save outputs
terraform output -json > outputs.json
```

## Step 3: Configure kubectl (2 minutes)

```bash
# Get AKS credentials (requires VNet access via VPN/jumpbox)
az aks get-credentials \
  --name $(terraform output -raw aks_name) \
  --resource-group $(terraform output -raw resource_group_name)

# Verify access
kubectl get nodes
```

## Step 4: Install ArgoCD (5 minutes)

```bash
# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer

# Get initial password
argocd admin initial-password -n argocd

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD at `https://localhost:8080` with username `admin` and the retrieved password.

## Step 5: Configure GitOps Repository (5 minutes)

```bash
# In your GitOps repository
mkdir -p apps/production/sample-app

# Copy application manifests
cp argocd-apps/blue-green/application.yaml <gitops-repo>/apps/production/sample-app/
cp argocd-apps/blue-green/values.yaml <gitops-repo>/apps/production/sample-app/

# Update values.yaml with your specific values:
# - image.repository (ACR login server)
# - workloadIdentity.client-id (from Terraform output)
# - secrets.keyvault.name (from Terraform output)
# - secrets.keyvault.tenantId (your tenant ID)

# Commit and push
git add .
git commit -m "Add sample-app ArgoCD application"
git push origin main
```

## Step 6: Connect ArgoCD to GitOps Repository (2 minutes)

In ArgoCD UI:
1. Settings → Repositories → Connect Repo
2. Enter your GitOps repository URL
3. Configure authentication (SSH or HTTPS)
4. Click Connect

## Step 7: Deploy Application (3 minutes)

In ArgoCD UI:
1. Click "New App"
2. Enter application name: `sample-app-production`
3. Select project: `production` (create if needed)
4. Select repository: your GitOps repo
5. Path: `apps/production/sample-app`
6. Cluster: `https://kubernetes.default.svc`
7. Namespace: `production`
8. Click Create
9. Click Sync to deploy

## Step 8: Configure Azure DevOps (10 minutes)

### Create Service Connection

1. Azure DevOps → Project Settings → Service Connections
2. New service connection → Azure Resource Manager
3. Use Workload Identity Federation (recommended)
4. Configure with your subscription

### Create Variable Group

Create a variable group with these values:

| Variable | Source |
|----------|--------|
| ACR_NAME | `terraform output -raw acr_name` |
| ACR_LOGIN_SERVER | `terraform output -raw acr_login_server` |
| AKS_NAME | `terraform output -raw aks_name` |
| AKS_RESOURCE_GROUP | `terraform output -raw resource_group_name` |
| KEYVAULT_NAME | `terraform output -raw key_vault_name` |
| AZURE_TENANT_ID | Your Azure AD tenant ID |
| WORKLOAD_IDENTITY_CLIENT_ID | `terraform output -json | jq -r '.workload_identity_client_ids.sample-app'` |

### Import Pipelines

1. Pipelines → Create Pipeline
2. Existing Azure Pipeline YAML
3. Select `pipelines/ci-build.yml`
4. Configure triggers and variable group
5. Repeat for `pipelines/cd-deploy.yml`

## Step 9: Add Key Vault Secrets (2 minutes)

```bash
KV_NAME=$(terraform output -raw key_vault_name)

# Add your secrets
az keyvault secret set \
  --vault-name $KV_NAME \
  --name database-connection-string \
  --value "your-connection-string"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name api-key \
  --value "your-api-key"
```

## Step 10: Deploy Your Application

1. Push your application code to the repository
2. CI pipeline builds and pushes image to ACR
3. CD pipeline updates GitOps repository
4. ArgoCD automatically syncs and deploys

## Verification

```bash
# Check deployment status
kubectl get pods -n production -l app=sample-app

# Check service
kubectl get svc sample-app -n production

# View logs
kubectl logs -n production -l app=sample-app,color=blue

# Port-forward to test
kubectl port-forward svc/sample-app -n production 8080:80
curl http://localhost:8080/health/ready
```

## Blue-Green Deployment

```bash
# Deploy new version (triggered by CI/CD)
# After deployment, switch traffic:

./scripts/deploy.sh switch-color production sample-app green

# Or via Helm:
helm upgrade sample-app ./helm-charts/sample-app \
  --namespace production \
  --reuse-values \
  --set deployment.activeColor=green

# Rollback if needed:
./scripts/deploy.sh rollback production sample-app
```

## Quick Reference

### Terraform Commands

```bash
terraform init              # Initialize working directory
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform destroy           # Destroy infrastructure
terraform output            # Show outputs
```

### kubectl Commands

```bash
kubectl get nodes           # List nodes
kubectl get pods -A         # List all pods
kubectl logs <pod>          # View logs
kubectl describe <resource> # View details
```

### Helm Commands

```bash
helm install <release> <chart>    # Install chart
helm upgrade <release> <chart>    # Upgrade release
helm uninstall <release>          # Uninstall release
helm list -n <namespace>          # List releases
```

### ArgoCD Commands

```bash
argocd app list                   # List applications
argocd app get <app>              # Get app details
argocd app sync <app>             # Sync application
argocd app logs <app>             # View app logs
```

## Troubleshooting

- **Cannot access AKS**: Ensure VPN/jumpbox connection to VNet
- **Image pull errors**: Check ACR private endpoint and DNS
- **Secret access issues**: Verify workload identity configuration
- **ArgoCD sync failures**: Check repository connection and Helm values

For detailed troubleshooting, see [docs/troubleshooting.md](docs/troubleshooting.md).

## Next Steps

- Set up monitoring (Prometheus, Grafana)
- Configure logging (Loki, Fluent Bit)
- Implement network policies
- Set up automated testing
- Configure backup and disaster recovery

## Support

- Platform Team: platform@company.com
- Documentation: [docs/](docs/)
- Azure Support: Azure Portal
