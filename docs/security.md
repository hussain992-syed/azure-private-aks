# Security Documentation

This document describes the security features and best practices implemented in this private Azure AKS infrastructure.

## Security Architecture Overview

### Network Security

#### Private Network Isolation

- **Private AKS Cluster**: No public API server endpoint. Access only via private network
- **Private ACR**: Container registry accessible only via private endpoint
- **Private Key Vault**: Secrets accessible only via private endpoint
- **VNet Isolation**: All resources in a dedicated virtual network with no public exposure

#### Network Security Groups (NSGs)

- **AKS Subnet NSG**:
  - Allows inter-node communication
  - Allows Azure Load Balancer health probes
  - Denies all other inbound traffic
  - Outbound traffic controlled by route table

- **Jumpbox Subnet NSG**:
  - Allows SSH only from specified admin CIDR blocks
  - Denies all other inbound traffic

#### Private Endpoints

All PaaS services use private endpoints:
- ACR: `privatelink.azurecr.io`
- Key Vault: `privatelink.vaultcore.azure.net`

Private DNS zones are configured to resolve these endpoints within the VNet.

### Identity and Access Management

#### Azure AD Integration

- **Azure AD RBAC**: Enabled for AKS cluster management
- **Local Accounts Disabled**: Only Azure AD authentication allowed
- **Admin Groups**: Specific Azure AD groups have cluster admin access
- **Managed Identity**: AKS uses user-assigned managed identity for Azure resource access

#### Workload Identity

Azure AD Workload Identity is used for pod-to-Azure service authentication:

- **No Secrets**: No credentials stored in Kubernetes secrets
- **Federated Credentials**: OIDC federation between AKS and Azure AD
- **Least Privilege**: Each workload has a dedicated identity with minimal permissions
- **Service Account Annotation**: Service accounts annotated with workload identity client ID

**Configuration Example**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sample-app-sa
  annotations:
    azure.workload.identity/client-id: <client-id>
```

**Federated Credential**:
- Issuer: AKS OIDC issuer URL
- Subject: `system:serviceaccount:<namespace>:<service-account-name>`
- Audience: `api://AzureADTokenExchange`

### Key Vault Security

#### Access Control

- **RBAC Authorization**: Key Vault uses Azure RBAC (not access policies)
- **Role Assignments**:
  - Key Vault Secrets Officer: Azure DevOps service principal
  - Key Vault Secrets User: Workload identities (read-only)
  - Key Vault Certificate User: AKS cluster identity

#### Protection Features

- **Soft Delete**: 90-day retention
- **Purge Protection**: Enabled (production)
- **Public Network Access**: Disabled
- **Private Endpoint**: Only accessible via private network

#### Secret Management

- **CSI Driver**: Secrets Store CSI Driver mounts secrets to pods
- **Automatic Rotation**: Secrets rotated every 2 minutes
- **No Hardcoded Secrets**: All secrets retrieved from Key Vault at runtime

### Container Security

#### Image Security

- **Private ACR**: Images stored in private registry
- **Content Trust**: Optional image signing support
- **Vulnerability Scanning**: Trivy scans integrated in CI pipeline
- **No Admin Account**: ACR admin account disabled

#### Runtime Security

- **Security Context**:
  - Run as non-root user
  - Read-only root filesystem
  - Drop all capabilities
  - Seccomp profile: RuntimeDefault

- **Pod Security Standards**:
  - Enforced via Pod Security Admission
  - Baseline policy applied to all namespaces

### Kubernetes Security

#### Network Policies

- **Calico**: Network policy engine enabled
- **Default Deny**: All pod-to-pod traffic denied by default
- **Explicit Allow**: Only required traffic allowed via policies

#### RBAC

- **Azure AD RBAC**: Cluster-level access via Azure AD
- **Kubernetes RBAC**: Namespace-level permissions
- **Role-Based**: Least-privilege roles for different teams

#### Admission Controllers

- **ValidatingAdmissionWebhook**: Custom validation rules
- **MutatingAdmissionWebhook**: Automatic injection of security configurations
- **Pod Security Admission**: Enforce pod security standards

### CI/CD Security

#### Azure DevOps Security

- **Workload Identity Federation**: No long-lived secrets in pipelines
- **Service Connection**: Uses federated identity
- **Variable Groups**: Sensitive values stored in Azure Key Vault
- **Branch Protection**: Pull requests required for main branch

#### Pipeline Security

- **Image Scanning**: Trivy scans before push
- **Secret Scanning**: Detects secrets in code
- **Signed Commits**: GPG signing recommended
- **Approval Gates**: Manual approval for production deployments

## Security Best Practices

### 1. Zero Trust Network

- No implicit trust based on network location
- All traffic authenticated and authorized
- Micro-segmentation with network policies

### 2. Least Privilege Access

- Each identity has minimum required permissions
- Regular access reviews
- Just-in-time access for privileged operations

### 3. Secrets Management

- No secrets in code or configuration
- Use Key Vault for all secrets
- Rotate secrets regularly
- Audit secret access

### 4. Immutable Infrastructure

- Infrastructure as code (Terraform)
- No manual changes to resources
- Version-controlled configurations
- Drift detection

### 5. Supply Chain Security

- Sign container images
- Verify image signatures at runtime
- Use trusted base images
- Scan for vulnerabilities

### 6. Monitoring and Auditing

- Log all access to sensitive resources
- Monitor for anomalous behavior
- Alert on security events
- Regular security audits

## Compliance Considerations

### SOC 2

- **Access Control**: Azure AD RBAC with audit trails
- **Data Encryption**: All data encrypted at rest and in transit
- **Change Management**: All changes via IaC with approvals
- **Incident Response**: Automated monitoring and alerting

### PCI DSS

- **Network Segmentation**: Isolated VNet with private endpoints
- **Access Control**: Multi-factor authentication for admin access
- **Data Protection**: Encryption of sensitive data
- **Logging**: Comprehensive audit logging

### GDPR

- **Data Residency**: Specify Azure region for data residency
- **Right to Erasure**: Automated data deletion workflows
- **Data Breach Notification**: Automated alerting
- **Consent Management**: User consent tracking

## Security Checklist

### Before Deployment

- [ ] Admin CIDR blocks configured
- [ ] Azure AD admin groups created
- [ ] Service principals with minimal permissions
- [ ] Network security groups reviewed
- [ ] Private DNS zones configured
- [ ] Key Vault access policies reviewed

### After Deployment

- [ ] Verify no public IP addresses on AKS, ACR, Key Vault
- [ ] Test private endpoint connectivity
- [ ] Verify workload identity federation
- [ ] Test secret access from pods
- [ ] Review Azure AD sign-in logs
- [ ] Configure security alerts

### Ongoing

- [ ] Regular access reviews
- [ ] Secret rotation schedule
- [ ] Vulnerability scanning
- [ ] Security patching
- [ ] Compliance audits
- [ ] Incident response drills

## Incident Response

### Security Incident Procedure

1. **Detection**
   - Monitor Azure Security Center alerts
   - Review Azure AD sign-in logs
   - Check AKS audit logs

2. **Containment**
   - Isolate affected resources
   - Revoke compromised credentials
   - Scale down affected services

3. **Eradication**
   - Identify root cause
   - Patch vulnerabilities
   - Remove malicious artifacts

4. **Recovery**
   - Restore from backups if needed
   - Re-deploy clean infrastructure
   - Verify system integrity

5. **Post-Incident**
   - Document incident
   - Update security controls
   - Conduct lessons learned

### Emergency Contacts

- Security Team: security@company.com
- Platform Team: platform@company.com
- Azure Support: Azure portal

## References

- [Azure Private AKS Best Practices](https://docs.microsoft.com/azure/aks/private-clusters)
- [Azure Workload Identity](https://docs.microsoft.com/azure/aks/workload-identity-overview)
- [Key Vault Security](https://docs.microsoft.com/azure/key-vault/general/security-overview)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Azure Foundation Benchmark](https://www.cisecurity.org/benchmark/azure)
