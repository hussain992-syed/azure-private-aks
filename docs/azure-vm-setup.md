# Azure VM Setup Guide

This guide explains how to set up your Azure VM to deploy the private AKS infrastructure using Terraform.

## Prerequisites

- Azure VM created with:
  - Ubuntu 22.04 LTS (recommended)
  - At least 2 vCPUs and 4GB RAM
  - Public IP with SSH access
  - Network Security Group allowing SSH from your IP

## Step 1: SSH into the Azure VM

```bash
ssh azureuser@<your-vm-public-ip>
```

## Step 2: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

## Step 3: Install Required Tools

### Install Azure CLI

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az --version
```

### Authenticate with Azure

```bash
az login
```

This will open a browser window. Complete the authentication.

Set your subscription:

```bash
az account set --subscription <your-subscription-id>
```

### Install Terraform

```bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

### Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Install Git

```bash
sudo apt install -y git
git --version
```

### Install jq (for JSON parsing)

```bash
sudo apt install -y jq
```

## Step 4: Clone or Copy Project Files

### Option A: Clone from Git Repository

```bash
git clone <your-git-repository-url> azure-private-aks
cd azure-private-aks
```

### Option B: Copy Files via SCP

From your local machine:

```bash
scp -r /Users/hussain/CascadeProjects/azure-private-aks azureuser@<vm-ip>:~/
```

Then on the VM:

```bash
cd ~/azure-private-aks
```

## Step 5: Navigate to Terraform Directory

```bash
cd terraform/environments/dev
```

## Step 6: Verify terraform.tfvars

Ensure `terraform.tfvars` is configured with your values:

```bash
cat terraform.tfvars
```

It should contain:
- `admin_cidr_blocks`: ["20.42.8.84/32"]
- `admin_group_object_ids`: ["f425756f-e730-499c-a472-1efd5256a40a"]
- `devops_service_principal_id`: "6529cc88-8628-4616-8cc1-135687b258cc"
- `terraform_sp_object_id`: "4b91e475-9e1e-4acb-a12a-00efbc902982"

## Step 7: Initialize Terraform

```bash
terraform init
```

## Step 8: Validate Configuration

```bash
terraform validate
```

## Step 9: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan to ensure it matches your expectations.

## Step 10: Apply Infrastructure

```bash
terraform apply tfplan
```

This will take 20-30 minutes to complete.

## Step 11: Save Outputs

```bash
terraform output -json > outputs.json
terraform output
```

Save the outputs for later use:
- `aks_name`
- `acr_login_server`
- `key_vault_name`
- `key_vault_uri`
- `workload_identity_client_ids`

## Step 12: Configure kubectl

Since AKS is private, you need to access it from within the VNet. You have two options:

### Option A: Use the Azure VM (already in VNet)

```bash
az aks get-credentials \
  --name $(terraform output -raw aks_name) \
  --resource-group $(terraform output -raw resource_group_name)

kubectl get nodes
```

### Option B: Set up VPN or Bastion

For access from your local machine, you'll need to set up:
- Azure VPN Gateway
- Azure Bastion
- Or use the Azure VM as a jumpbox

## Step 13: Install ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer
```

Get initial password:

```bash
argocd admin initial-password -n argocd
```

## Step 14: Access ArgoCD UI

Port-forward to access ArgoCD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at `https://localhost:8080` with username `admin` and the retrieved password.

## Troubleshooting

### Terraform Init Fails

```bash
# Check Azure CLI authentication
az account show

# Re-authenticate if needed
az login
```

### Permission Errors

Ensure your service principal has the correct permissions:
- Contributor on the subscription
- Azure AD permissions for group management

### Network Issues

- Ensure the VM can reach Azure APIs
- Check NSG rules allow outbound internet access
- Verify DNS resolution

### Out of Memory

If the VM runs out of memory during Terraform apply:
- Increase VM size (e.g., to Standard_DS3_v2)
- Run Terraform apply in smaller batches using `-target`

## Next Steps

After infrastructure is deployed:

1. Set up GitOps repository
2. Configure Azure DevOps pipelines
3. Add Key Vault secrets
4. Deploy your application

See [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) for detailed instructions.
