# Troubleshooting Guide

This guide helps diagnose and resolve common issues with the private Azure AKS infrastructure.

## Table of Contents

- [Infrastructure Issues](#infrastructure-issues)
- [AKS Cluster Issues](#aks-cluster-issues)
- [ACR Issues](#acr-issues)
- [Key Vault Issues](#key-vault-issues)
- [ArgoCD Issues](#argocd-issues)
- [Application Deployment Issues](#application-deployment-issues)
- [Blue-Green Deployment Issues](#blue-green-deployment-issues)
- [CI/CD Pipeline Issues](#cicd-pipeline-issues)

## Infrastructure Issues

### Cannot Access Private AKS API Server

**Symptoms**:
- `kubectl get nodes` times out
- Connection refused errors
- Unable to get AKS credentials

**Causes**:
- Not connected to VNet (VPN/jumpbox required)
- Private DNS zone not configured
- Network connectivity issues

**Solutions**:

1. Verify you're connected to the VNet:
```bash
# Check VPN connection
ping 10.0.0.1  # AKS subnet gateway

# Or verify jumpbox connectivity
ssh user@jumpbox.fqdn
```

2. Check private DNS zone:
```bash
# Verify private DNS zone exists
az network private-dns zone show \
  --name privatelink.<region>.azmk8s.io \
  --resource-group <rg-name>

# Verify VNet link
az network private-dns link show \
  --zone-name privatelink.<region>.azmk8s.io \
  --name aks-link \
  --resource-group <rg-name>
```

3. Test DNS resolution:
```bash
nslookup <aks-name>.<region>.azmk8s.io
```

4. Check AKS API server subnet connectivity:
```bash
# From jumpbox
telnet <aks-api-server-ip> 443
```

### Terraform Apply Fails with Timeout

**Symptoms**:
- Terraform apply hangs
- Timeout errors during resource creation
- Partial resource creation

**Causes**:
- Azure API rate limiting
- Network connectivity issues
- Resource dependencies not satisfied

**Solutions**:

1. Increase Terraform timeout:
```bash
terraform apply -timeout=30m
```

2. Check Azure CLI authentication:
```bash
az account show
az account get-access-token
```

3. Apply in smaller batches:
```bash
terraform apply -target=module.networking
terraform apply -target=module.acr
terraform apply -target=module.aks
```

4. Check resource group quota:
```bash
az quota show --scope /subscriptions/<sub-id>/providers/Microsoft.Compute/locations/<location>/quotas
```

## AKS Cluster Issues

### Pods Cannot Pull Images from ACR

**Symptoms**:
- `ImagePullBackOff` or `ErrImagePull` errors
- Pod events show authentication failures

**Causes**:
- ACR private endpoint not accessible
- AKS kubelet identity lacks AcrPull role
- Private DNS misconfiguration

**Solutions**:

1. Verify ACR private endpoint:
```bash
az network private-endpoint show \
  --name <acr-pe-name> \
  --resource-group <rg-name>
```

2. Check kubelet identity role assignment:
```bash
az role assignment list \
  --assignee <kubelet-identity-object-id> \
  --scope <acr-id>
```

3. Test DNS resolution from AKS node:
```bash
# Get node shell (requires privileged access)
kubectl debug node/<node-name> -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0

# Inside debug container
nslookup <acr-name>.azurecr.io
```

4. Verify private DNS zone:
```bash
az network private-dns zone show \
  --name privatelink.azurecr.io \
  --resource-group <rg-name>
```

### Workload Identity Not Working

**Symptoms**:
- Pods cannot access Key Vault
- `AADSTS700016` errors
- Token acquisition failures

**Causes**:
- Service account missing annotation
- Federated credential misconfigured
- OIDC issuer URL incorrect

**Solutions**:

1. Verify service account annotation:
```bash
kubectl get sa sample-app-sa -n production -o yaml
# Check for: azure.workload.identity/client-id
```

2. Check federated credential:
```bash
az identity federated-credential list \
  --identity-name <identity-name> \
  --resource-group <rg-name>
```

3. Verify OIDC issuer URL:
```bash
az aks show \
  --name <aks-name> \
  --resource-group <rg-name> \
  --query oidcIssuerUrl
```

4. Check pod labels:
```bash
kubectl get pod <pod-name> -n production -o yaml
# Should have: azure.workload.identity/use: "true"
```

5. Test token acquisition from pod:
```bash
kubectl exec -it <pod-name> -n production -- sh
curl -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net&client_id=<client-id>"
```

### Pods in CrashLoopBackOff

**Symptoms**:
- Pod status: `CrashLoopBackOff`
- Application keeps restarting

**Causes**:
- Application errors
- Missing environment variables
- Secret access issues
- Resource constraints

**Solutions**:

1. Check pod logs:
```bash
kubectl logs <pod-name> -n production --previous
```

2. Check pod events:
```bash
kubectl describe pod <pod-name> -n production
```

3. Verify secrets are mounted:
```bash
kubectl exec -it <pod-name> -n production -- env | grep DATABASE
```

4. Check resource limits:
```bash
kubectl top pod <pod-name> -n production
```

5. Check SecretProviderClass:
```bash
kubectl get secretproviderclass -n production
kubectl describe secretproviderclass <spc-name> -n production
```

## ACR Issues

### Cannot Push Images to ACR

**Symptoms**:
- `unauthorized: authentication required`
- Permission denied errors

**Causes**:
- Service principal lacks AcrPush role
- Authentication token expired
- Network connectivity issues

**Solutions**:

1. Verify service principal role:
```bash
az role assignment list \
  --assignee <sp-object-id> \
  --scope <acr-id> \
  --role "AcrPush"
```

2. Re-authenticate:
```bash
az acr login --name <acr-name>
```

3. Test network connectivity:
```bash
# From your machine
telnet <acr-name>.azurecr.io 443
```

4. Check ACR private endpoint:
```bash
az network private-endpoint show \
  --name <acr-pe-name> \
  --resource-group <rg-name>
```

### Image Pull Fails with Timeout

**Symptoms**:
- Image pull timeout errors
- Slow image pulls

**Causes**:
- Network latency
- ACR private endpoint issues
- DNS resolution problems

**Solutions**:

1. Test DNS resolution:
```bash
nslookup <acr-name>.azurecr.io
```

2. Check private endpoint connection:
```bash
az network private-endpoint show \
  --name <acr-pe-name> \
  --resource-group <rg-name> \
  --query "{status:properties.privateLinkServiceConnectionState.status}"
```

3. Check network latency:
```bash
ping <acr-private-ip>
```

4. Verify ACR is accessible:
```bash
az acr check-health --name <acr-name>
```

## Key Vault Issues

### Cannot Access Secrets from Pods

**Symptoms**:
- Secrets not mounted
- CSI driver errors
- Permission denied

**Causes**:
- Workload identity not configured
- SecretProviderClass misconfigured
- Role assignment missing

**Solutions**:

1. Check CSI driver pods:
```bash
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
```

2. Check SecretProviderClass:
```bash
kubectl get secretproviderclass -n production
kubectl describe secretproviderclass <spc-name> -n production
```

3. Verify role assignment:
```bash
az role assignment list \
  --assignee <workload-identity-principal-id> \
  --scope <key-vault-id> \
  --role "Key Vault Secrets User"
```

4. Check pod volume mounts:
```bash
kubectl describe pod <pod-name> -n production | grep -A 10 "Mounts"
```

5. Check CSI driver logs:
```bash
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

### Key Vault Access Denied

**Symptoms**:
- `Access Denied` errors
- 403 Forbidden

**Causes**:
- Incorrect role assignment
- Network policy blocking access
- Private endpoint issues

**Solutions**:

1. Verify role assignment:
```bash
az role assignment list \
  --assignee <principal-id> \
  --scope <key-vault-id>
```

2. Check network policies:
```bash
kubectl get networkpolicy -n production
```

3. Verify private endpoint:
```bash
az network private-endpoint show \
  --name <kv-pe-name> \
  --resource-group <rg-name>
```

4. Test from pod:
```bash
kubectl exec -it <pod-name> -n production -- sh
curl -v https://<kv-name>.vaultcore.azure.net/
```

## ArgoCD Issues

### Application Not Syncing

**Symptoms**:
- ArgoCD shows "OutOfSync"
- Manual sync fails
- No automatic sync

**Causes**:
- Repository connection issues
- Invalid Helm values
- Resource conflicts

**Solutions**:

1. Check repository connection:
```bash
argocd repo list
argocd repo get <repo-url>
```

2. Test repository access:
```bash
git ls-remote <repo-url>
```

3. Check application status:
```bash
argocd app get sample-app-production
```

4. View sync errors:
```bash
argocd app logs sample-app-production
```

5. Force sync:
```bash
argocd app sync sample-app-production --force
```

### ArgoCD UI Not Accessible

**Symptoms**:
- Cannot access ArgoCD UI
- Connection timeout

**Causes**:
- Service not exposed
- Ingress misconfiguration
- Network policies

**Solutions**:

1. Check ArgoCD pods:
```bash
kubectl get pods -n argocd
```

2. Check service:
```bash
kubectl get svc -n argocd
```

3. Port-forward for testing:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

4. Check ingress:
```bash
kubectl get ingress -n argocd
```

5. Check network policies:
```bash
kubectl get networkpolicy -n argocd
```

## Application Deployment Issues

### Helm Chart Installation Fails

**Symptoms**:
- Helm install errors
- Template rendering errors
- Values validation errors

**Causes**:
- Invalid values
- Missing required parameters
- Template syntax errors

**Solutions**:

1. Validate Helm chart:
```bash
helm lint ./helm-charts/sample-app
```

2. Dry-run install:
```bash
helm install sample-app ./helm-charts/sample-app \
  --namespace production \
  --dry-run --debug
```

3. Check values:
```bash
helm show values ./helm-charts/sample-app
```

4. Install with verbose output:
```bash
helm install sample-app ./helm-charts/sample-app \
  --namespace production \
  --values argocd-apps/blue-green/values.yaml \
  --debug
```

### Service Not Accessible

**Symptoms**:
- Cannot connect to application
- Connection refused
- DNS resolution fails

**Causes**:
- Service selector mismatch
- Pod not ready
- Network policies blocking

**Solutions**:

1. Check service:
```bash
kubectl get svc sample-app -n production
kubectl describe svc sample-app -n production
```

2. Check service endpoints:
```bash
kubectl get endpoints sample-app -n production
```

3. Check pod labels:
```bash
kubectl get pods -n production -l app=sample-app,color=blue --show-labels
```

4. Check network policies:
```bash
kubectl get networkpolicy -n production
```

5. Port-forward for testing:
```bash
kubectl port-forward svc/sample-app -n production 8080:80
```

## Blue-Green Deployment Issues

### Traffic Not Switching

**Symptoms**:
- Service selector not updated
- Old color still receiving traffic
- Helm upgrade not reflecting changes

**Causes**:
- Helm values not applied
- Service selector annotation issue
- ArgoCD sync delay

**Solutions**:

1. Check current active color:
```bash
kubectl get svc sample-app -n production -o jsonpath='{.spec.selector.color}'
```

2. Check deployment status:
```bash
kubectl get deployment -n production
```

3. Manually update service selector:
```bash
kubectl patch svc sample-app -n production \
  -p '{"spec":{"selector":{"color":"green"}}}'
```

4. Force ArgoCD sync:
```bash
argocd app sync sample-app-production
```

5. Use deployment script:
```bash
./scripts/deploy.sh switch-color production sample-app green
```

### Rollback Fails

**Symptoms**:
- Cannot rollback to previous version
- Previous deployment not available
- Rollback command errors

**Causes**:
- Previous deployment scaled to 0
- Image deleted from ACR
- Helm release history issue

**Solutions**:

1. Check previous deployment:
```bash
kubectl get deployment -n production
kubectl get pods -n production -l app=sample-app
```

2. Check Helm history:
```bash
helm history sample-app -n production
```

3. Manual rollback:
```bash
helm rollback sample-app -n production
```

4. Scale up previous deployment:
```bash
kubectl scale deployment sample-app-blue -n production --replicas=3
```

5. Switch traffic:
```bash
./scripts/deploy.sh switch-color production sample-app blue
```

## CI/CD Pipeline Issues

### Azure DevOps Pipeline Fails

**Symptoms**:
- Pipeline execution fails
- Build errors
- Deployment errors

**Causes**:
- Service connection issues
- Variable group misconfiguration
- Authentication failures

**Solutions**:

1. Check service connection:
```bash
# In Azure DevOps UI
# Project Settings → Service Connections → Verify connection
```

2. Check variable group:
```bash
# Verify all required variables are set
# Check secret values are not expired
```

3. View pipeline logs:
```bash
# In Azure DevOps UI
# Pipelines → Runs → Select run → View logs
```

4. Test service principal authentication:
```bash
az login --service-principal \
  -u <client-id> \
  -p <client-secret> \
  --tenant <tenant-id>
```

### Image Build Fails

**Symptoms**:
- ACR build fails
- Docker build errors
- Build timeout

**Causes**:
- Dockerfile errors
- Build context issues
- Resource constraints

**Solutions**:

1. Test Dockerfile locally:
```bash
docker build -t test-image -f Dockerfile .
```

2. Check ACR build logs:
```bash
az acr build-task logs \
  --registry <acr-name> \
  --task <task-id>
```

3. Verify build context:
```bash
# Check that all required files are in the build context
ls -la <build-context>
```

4. Increase build timeout:
```bash
az acr build \
  --registry <acr-name> \
  --image <image-name> \
  --file Dockerfile \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --timeout 3600 \
  <build-context>
```

## Getting Help

### Collect Diagnostic Information

When seeking help, collect the following information:

```bash
# System information
terraform version
az version
kubectl version
helm version

# Infrastructure state
terraform show

# Cluster state
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Application state
kubectl get all -n production
kubectl describe deployment sample-app-blue -n production
kubectl logs -n production -l app=sample-app,color=blue

# ArgoCD state
argocd app list
argocd app get sample-app-production
```

### Log Collection

```bash
# Collect all logs
kubectl logs -n production --all-containers=true -l app=sample-app > app-logs.txt
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server > argocd-logs.txt
kubectl logs -n kube-system -l app=secrets-store-csi-driver > csi-logs.txt
```

### Support Channels

- **Platform Team**: platform@company.com
- **Azure Support**: Azure Portal → Help + Support
- **Terraform Issues**: https://github.com/hashicorp/terraform/issues
- **ArgoCD Issues**: https://github.com/argoproj/argo-cd/issues
