
# AWS EKS Cluster with Managed Node Group (Terraform)

This module provisions an AWS EKS cluster with managed node groups using Terraform. It covers all resources from IAM roles to cluster and node group creation. VPC setup is included for completeness but not explained in detail here.

---

## Resource-by-Resource Explanation

### 1. VPC & Networking Resources
- `aws_vpc.this`: Main VPC for the cluster.
- `aws_subnet.*`: Public and private subnets for nodes and load balancers.
- `aws_internet_gateway.igw`, `aws_nat_gateway.nat`, `aws_eip.nat`: Internet and NAT gateways for routing.
- `aws_route_table.*`, `aws_route.*`, `aws_route_table_association.*`: Routing tables and associations for public/private traffic.

### 2. EKS Cluster IAM Role (`aws_iam_role.cluster`)
- IAM role for the EKS control plane to interact with AWS services.
- Trust policy allows `eks.amazonaws.com` to assume the role.

### 3. EKS Cluster Role Policy Attachments
- `AmazonEKSClusterPolicy`: Allows EKS to manage clusters.
- `AmazonEKSServicePolicy`: Allows EKS to manage AWS resources for add-ons.

### 4. EKS Cluster (`aws_eks_cluster.this`)
- Creates the EKS control plane (Kubernetes master nodes managed by AWS).
- References VPC and private subnet IDs for networking.
- Uses the IAM role above for permissions.
- Enables public/private API endpoints.

### 5. Node Group IAM Role (`aws_iam_role.node`)
- IAM role for EC2 instances in the managed node group.
- Trust policy allows `ec2.amazonaws.com` to assume the role.

### 6. Node Group Role Policy Attachments
- `AmazonEKSWorkerNodePolicy`: Allows nodes to connect to EKS.
- `AmazonEC2ContainerRegistryReadOnly`: Allows pulling images from ECR.
- `AmazonEKS_CNI_Policy`: Allows networking for pods.

### 7. Managed Node Group (`aws_eks_node_group.default`)
- Creates a managed group of EC2 worker nodes that auto-join the EKS cluster.
- Specifies instance type, scaling (min/max/desired), and subnets.
- Uses the node group IAM role.
- Sets AMI type, disk size, and tags.

### 8. IRSA: OIDC Provider for the Cluster
- `aws_iam_openid_connect_provider.eks`: Enables OIDC for IRSA (IAM Roles for Service Accounts).
- `data.tls_certificate.oidc`: Gets OIDC thumbprint for trust policy.

### 9. ALB Controller IRSA Setup
- `aws_iam_policy.alb_controller`: IAM policy for ALB controller (from JSON file).
- `data.aws_iam_policy_document.alb_controller_trust`: Trust policy for ALB controller service account.
- `aws_iam_role.alb_controller`: IAM role for ALB controller.
- `aws_iam_role_policy_attachment.alb_controller_attach`: Attaches policy to role.
- `kubernetes_service_account.alb_sa`: Service account for ALB controller, annotated for IRSA.
- `helm_release.alb_controller`: Installs ALB controller via Helm, using the IRSA-enabled service account.

### 10. VPC CNI Plugin IRSA Setup
- `aws_iam_policy.vpc_cni`: IAM policy for VPC CNI plugin (ENI management).
- `data.aws_iam_policy_document.vpc_cni_trust`: Trust policy for VPC CNI service account.
- `aws_iam_role.vpc_cni`: IAM role for VPC CNI plugin.
- `aws_iam_role_policy_attachment.vpc_cni_attach`: Attaches policy to role.
- Service account `aws-node` (created by EKS) must be annotated manually for IRSA.

### 11. Example: Pod Access to S3 via IRSA
- Example resources (commented): IAM policy, trust policy, IAM role, role attachment, and service account for a pod needing S3 access.
- Shows how to grant least-privilege AWS access to specific pods using IRSA.

### 12. (Optional) Security Groups
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


## Granting Kubernetes Deploy-Only Access to a Colleague

If your colleague only needs to deploy applications to EKS (using kubectl/Helm), follow these steps to grant limited Kubernetes access:

### 1. Create IAM User (if not already existing)
- Go to AWS Console → IAM → Users → Add user.
- Select "Programmatic access" only.
- No need to attach any AWS policies except basic EKS access (for `aws eks update-kubeconfig`).

### 2. Map IAM User to Kubernetes RBAC
- Edit the EKS `aws-auth` ConfigMap:
	```sh
	kubectl edit configmap aws-auth -n kube-system
	```
- Add under `mapUsers`:
	```yaml
	- userarn: arn:aws:iam::<account-id>:user/<username>
		username: <username>
		groups:
			- eks-deployer
	```

### 3. Create RBAC Role and Binding
Create a file `eks-deployer-rbac.yaml` with the following content:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
	name: eks-deployer
rules:
	- apiGroups: ["", "apps", "batch", "extensions"]
		resources: ["pods", "deployments", "services", "replicasets", "jobs", "configmaps", "secrets"]
		verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
	name: eks-deployer-binding
subjects:
	- kind: User
		name: <username>
		apiGroup: rbac.authorization.k8s.io
roleRef:
	kind: ClusterRole
	name: eks-deployer
	apiGroup: rbac.authorization.k8s.io
```
Apply with:
```sh
kubectl apply -f eks-deployer-rbac.yaml
```

### 4. Share kubeconfig Setup Instructions
Ask your colleague to run:
```sh
aws eks update-kubeconfig --name <cluster-name> --region <region> --profile <their-aws-profile>
```
They can now use `kubectl`/Helm to deploy apps, but cannot manage nodes, networking, or cluster-wide resources.

---
**Note:**
- Only annotate service accounts for IRSA if pods need AWS access.
- For most users, RBAC is sufficient for application deployment.
---

## Kubernetes Service & Ingress: AWS EKS Load Balancer Behavior and Best Practices

### Service of type LoadBalancer
- **No ALB Controller installed:**
  - Default is Classic Load Balancer (CLB).
  - No annotations required for CLB.
- **ALB Controller installed:**
  - Default is Network Load Balancer (NLB).
  - No annotations required for NLB, but you can use annotations for advanced control.
- **Annotations for NLB:**
  - `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"` (explicitly requests NLB)
  - `service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"` (makes NLB public)
  - Omitting `internet-facing` or setting `service.beta.kubernetes.io/aws-load-balancer-internal: "true"` makes NLB internal.
- **References:**
  - [AWS EKS Network Load Balancing](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html#network-load-balancing-service-sample-manifest)

### Ingress (ALB Controller)
- **Ingress resource creates ALB (Application Load Balancer) when using AWS Load Balancer Controller.**
- **Key annotations:**
  - `alb.ingress.kubernetes.io/scheme: internet-facing` (public ALB)
  - `alb.ingress.kubernetes.io/target-type: ip` (recommended for pod-level routing; allows ClusterIP backend)
- **IngressClass:**
  - Use `spec.ingressClassName: alb` instead of deprecated `kubernetes.io/ingress.class` annotation.
- **Backend Service:**
  - For ALB Ingress, backend Service can be ClusterIP (recommended).
  - For NLB Ingress, backend Service must be NodePort or LoadBalancer if using Instance target type.
- **References:**
  - [AWS Load Balancer Controller Ingress Guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/)

### Common Findings & Troubleshooting
- If NLB is created as internal, check subnet tags and annotations.
- For public NLB, ensure public subnets are tagged `kubernetes.io/role/elb = 1` and use `internet-facing` annotation.
- For ALB Ingress, always use `alb.ingress.kubernetes.io/target-type: ip` if backend is ClusterIP.
- Deprecated annotations should be replaced with their respective spec fields (e.g., `spec.ingressClassName`).

---
