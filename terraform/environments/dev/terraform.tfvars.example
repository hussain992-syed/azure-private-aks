# Terraform Variables Example
# Copy this file to terraform.tfvars and update with your values

# Admin CIDR blocks (your IP addresses for SSH access)
# Get your public IP: curl ifconfig.me
admin_cidr_blocks = [
  "20.42.8.84/32"
]

# Azure AD Group Object IDs for cluster admin access
# Create a group in Azure AD and add your users
# Get group object ID: az ad group show --group "YourGroup" --query objectId -o tsv
admin_group_object_ids = [
  "f425756f-e730-499c-a472-1efd5256a40a"
]

# Azure DevOps Service Principal Object ID
# From the service principal created for CI/CD
# Get object ID: az ad sp show --id <app-id> --query objectId -o tsv
devops_service_principal_id = "6529cc88-8628-4616-8cc1-135687b258cc"

# Terraform Service Principal Object ID (for Key Vault access during deployment)
# From the service principal used to run Terraform
terraform_sp_object_id = "4b91e475-9e1e-4acb-a12a-00efbc902982"
