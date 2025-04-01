# ⚙️ EKS Organizational Considerations

When planning your EKS setup, there are a few different paths depending on your organization's structure and goals:

1. **Adopting an Existing EKS Cluster**  
   You may be joining a shared, pre-existing EKS cluster. In this case, focus will be on integrating your workloads while respecting existing networking, IAM, and RBAC constraints.

2. **Creating a Dedicated EKS Cluster for Your Stack**  
   You may want your own isolated EKS cluster for a specific environment, team, or bounded context. This can provide better separation, scaling independence, and security boundaries — especially if multiple teams or services are involved.

3. **Structuring for Multiple Services and ECR Repositories**  
   If you're planning to run multiple microservices, you’ll likely want to:
   - Create **individual ECR repositories per service** for clearer CI/CD ownership and versioning.
   - Organize Terraform modules and namespaces accordingly.
   - Reuse common infrastructure components (like VPCs or IAM roles) where appropriate.

These considerations will shape how you structure your Terraform/Terragrunt folders, tagging strategies, and resource boundaries.

This will also require you to adjust cluster names, role names or other to keep things consistent and unique.

## Common.hcl

See this file for all settings.

## Important (Provisioning)

Spinning this up the first time I would set `cluster_endpoint_public_access  = true`.
After provisioning you may `cluster_endpoint_public_access  = false`

### Why?

CoreDNS and other add-ons need to pull container images during setup.
Without public access, the control plane can't communicate with the pods unless you're inside the VPC.

## Debug VPC on Destroy

Things may connect to VPC, Subnets and cause issues on destroy

```bash
aws ec2 describe-addresses --filters "Name=network-interface-id,Values=*" --region us-west-2
aws ec2 release-address --allocation-id <your-allocation-id>
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=vpc-0baf82d68d911059f" --region us-west-2
aws ec2 delete-network-interface --network-interface-id <network-interface-id>
```
