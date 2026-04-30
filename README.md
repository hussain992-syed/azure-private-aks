# Private Azure AKS Infrastructure

This project implements a fully private and secure application deployment environment on Azure with AKS, ACR, and Key Vault.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure DevOps                                    │
│                    ┌─────────────────────────┐                              │
│                    │    CI/CD Pipeline       │                              │
│                    │  (Build → Push → Deploy) │                              │
│                    └───────────┬─────────────┘                              │
│                                │                                            │
│                     Build & Push to ACR                                     │
│                                │                                            │
│                    ┌───────────▼─────────────┐                              │
│                    │   Update Git Repo       │                              │
│                    │   (Helm chart version)  │                              │
│                    └───────────┬─────────────┘                              │
│                                │                                            │
└────────────────────────────────┼────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Private Network                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         Virtual Network                                │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────┐   │  │
│  │  │ AKS Subnet   │  │ ACR Subnet   │  │ KV Subnet    │  │ ArgoCD   │   │  │
│  │  │ 10.0.0.0/24  │  │ 10.0.1.0/24  │  │ 10.0.2.0/24  │  │ Subnet   │   │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────┬─────┘   │  │
│  │         │                 │                 │               │        │  │
│  │         └─────────────────┴─────────────────┘               │        │  │
│  │                           │                                  │        │  │
│  │                    Private Endpoints                         │        │  │
│  │                           │                                  │        │  │
│  │  ┌──────────────────────▼──────────────────────┐            │        │  │
│  │  │        Azure Private DNS Zones               │            │        │  │
│  │  │   (privatelink.azurecr.io,                   │            │        │  │
│  │  │    privatelink.vaultcore.azure.net)          │            │        │  │
│  │  └──────────────────────────────────────────────┘            │        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐  │
│  │   Azure Key Vault  │  │    Azure Container │  │  Private AKS Cluster│  │
│  │   (No Public Net)  │  │    Registry (ACR)  │  │  (No Public API)    │  │
│  │                    │  │    (No Public Net) │  │                     │  │
│  │  • Secrets         │  │                    │  │  • Workload Identity│  │
│  │  • Certificates    │  │  • Images stored   │  │  • Private API      │  │
│  │  • Keys            │  │    securely        │  │  • Managed Identity │  │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘  │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         ArgoCD (GitOps)                                ││
│  │  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   ││
│  │  │  Git Repository │────▶│  ArgoCD Server  │────▶│  Application    │   ││
│  │  │  (Helm Charts)  │     │  (in AKS)       │     │  Sync to AKS    │   ││
│  │  └─────────────────┘     └─────────────────┘     └─────────────────┘   ││
│  │                                                                          ││
│  │  ┌─────────────────────────────────────────────────────────────────────┐ ││
│  │  │                    Blue-Green Deployment                           │ ││
│  │  │  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐ │ ││
│  │  │  │   Blue       │◄───────►│  Service     │◄───────►│   Green      │ │ ││
│  │  │  │  (Active)    │         │  (Selector)  │         │  (Standby)   │ │ ││
│  │  │  └──────────────┘         └──────────────┘         └──────────────┘ │ ││
│  │  └─────────────────────────────────────────────────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
azure-private-aks/
├── terraform/
│   ├── modules/
│   │   ├── networking/       # VNet, subnets, NSGs, private endpoints
│   │   ├── acr/              # Azure Container Registry (private)
│   │   ├── aks/              # Private AKS cluster with workload identity
│   │   └── keyvault/         # Key Vault with private endpoint
│   └── environments/
│       ├── dev/              # Development environment
│       └── prod/             # Production environment
├── helm-charts/
│   ├── sample-app/           # Sample application Helm chart
│   └── argocd/               # ArgoCD installation values
├── pipelines/
│   ├── ci-pipeline.yml       # Build and push pipeline
│   └── cd-pipeline.yml       # Deploy pipeline (updates Git for ArgoCD)
├── argocd-apps/
│   ├── blue-green/           # Blue-green application definitions
│   └── rollouts/             # Argo Rollouts configuration
├── scripts/
│   ├── deploy.sh             # Deployment helper script
│   └── validate.sh           # Validation script
└── docs/
    ├── setup.md              # Setup instructions
    ├── security.md           # Security documentation
    └── troubleshooting.md    # Troubleshooting guide
```

## Key Features

- **Private AKS Cluster**: No public API server endpoint, access via private network only
- **Private ACR**: Container registry accessible only via private endpoint
- **Private Key Vault**: Secrets accessible only via private endpoint with workload identity
- **Workload Identity**: Secure pod-to-Azure service authentication without secrets
- **ArgoCD GitOps**: Declarative continuous delivery with Git as single source of truth
- **Blue-Green Deployment**: Zero-downtime deployments with instant rollback capability

## Prerequisites

- Azure CLI (v2.50+)
- Terraform (v1.5+)
- kubectl
- Helm (v3.12+)
- Azure DevOps organization with service connection

## Quick Start

See [docs/setup.md](docs/setup.md) for detailed setup instructions.

## Security Highlights

- No public network access to AKS API, ACR, or Key Vault
- Private endpoints for all PaaS services
- Azure AD Workload Identity for secretless authentication
- Network policies for pod-to-pod traffic control
- Pod Security Standards enforced
- Least-privilege RBAC throughout
