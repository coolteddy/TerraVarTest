
# AWS EKS Cluster with Managed Node Group (Terraform)

This module provisions an AWS EKS cluster with managed node groups using Terraform. It covers all resources from IAM roles to cluster and node group creation. VPC setup is included for completeness but not explained in detail here.

---

## Resource-by-Resource Explanation

### 1. EKS Cluster IAM Role (`aws_iam_role.cluster`)
**Purpose:** IAM role for the EKS control plane to interact with AWS services.
- Trust policy allows `eks.amazonaws.com` to assume the role.
- Required for cluster creation.

### 2. EKS Cluster Role Policy Attachments
- `AmazonEKSClusterPolicy`: Allows EKS to manage clusters.
- `AmazonEKSServicePolicy`: Allows EKS to manage AWS resources for add-ons.

### 3. EKS Cluster (`aws_eks_cluster.this`)
**Purpose:** Creates the EKS control plane (Kubernetes master nodes managed by AWS).
- References VPC and private subnet IDs for networking.
- Uses the IAM role above for permissions.
- Enables public/private API endpoints.
- Can enable logging and add-ons.

### 4. Node Group IAM Role (`aws_iam_role.node`)
**Purpose:** IAM role for EC2 instances in the managed node group.
- Trust policy allows `ec2.amazonaws.com` to assume the role.
- Required for worker nodes to join the cluster and interact with AWS services.

### 5. Node Group Role Policy Attachments
- `AmazonEKSWorkerNodePolicy`: Allows nodes to connect to EKS.
- `AmazonEC2ContainerRegistryReadOnly`: Allows pulling images from ECR.
- `AmazonEKS_CNI_Policy`: Allows networking for pods.

### 6. Managed Node Group (`aws_eks_node_group.default`)
**Purpose:** Creates a managed group of EC2 worker nodes that auto-join the EKS cluster.
- Specifies instance type, scaling (min/max/desired), and subnets.
- Uses the node group IAM role.
- Sets AMI type, disk size, and tags.
- AWS manages lifecycle (upgrades, health, scaling).

### 7. (Optional) EKS Add-ons
- Core add-ons like CoreDNS, kube-proxy, and VPC CNI can be enabled for networking and DNS.
- Managed by AWS and can be updated independently.

### 8. (Optional) Security Groups
- Control network access to the cluster and nodes.
- Allow communication between nodes, control plane, and the internet as needed.

---

## How the Flow Works
1. EKS cluster role is created and attached with required policies.
2. EKS cluster is created, referencing the VPC and subnets.
3. Node group role is created and attached with node policies.
4. Managed node group is created, launching EC2 instances in the private subnets.
5. Add-ons are installed for networking and DNS.
6. Security groups ensure proper communication between all components.

---

## Usage
1. Set variables for cluster name, region, node instance type, and scaling.
2. Run `terraform init` and `terraform apply`.
3. Use `aws eks describe-cluster` to check cluster status.
4. Use `kubectl` (after updating kubeconfig) to interact with the cluster.
5. Deploy a test workload to verify node group functionality.

---

## Notes
- VPC, subnets, NAT, and routing are included for completeness.
- All resources are tagged for easy identification.
- For production, consider multi-AZ NAT gateways and custom security groups.
- For add-on management, see AWS EKS documentation.

## Helm ALB Controller Installation: Manual Step

If you see an error about locating the Helm chart ("no cached repo found"), run these commands before applying Terraform:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

This ensures the chart repository is available for Terraform's Helm provider.

## NGINX Quick Test Script

This repo includes `nginx_install.sh`, a helper script to quickly deploy an NGINX test workload to your EKS cluster and expose it via a public LoadBalancer service.

**Usage:**
1. Ensure you have AWS CLI and kubectl installed.
2. Edit the script to set your region and cluster name if needed.
3. Run:
	```bash
	bash nginx_install.sh
	```
4. Wait for the EXTERNAL-IP to appear, then test with:
	```bash
	curl http://<EXTERNAL-IP>
	```
5. To clean up:
	```bash
	kubectl delete -f nginx.yaml
	```

The script checks for required tools, updates kubeconfig, deploys NGINX, and provides cleanup instructions.

---

For troubleshooting, check CloudWatch logs, AWS console, and Terraform output. For more details, see the comments in `main.tf`.
