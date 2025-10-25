
#!/bin/bash
set -e

# Parameters
REGION="eu-west-1"
CLUSTER="burmanic-eks-demo"

# Check for required tools
command -v aws >/dev/null 2>&1 || { echo "aws CLI not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }

# Update kubeconfig and check nodes
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes || { echo "Failed to get nodes. Check your cluster."; exit 1; }

# Quick nginx test (creates a public LoadBalancer Service)
cat <<YAML > nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
  # annotations:
  #   service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  #   service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: web
YAML

kubectl apply -f nginx.yaml
echo "Waiting for EXTERNAL-IP. Use: kubectl get svc web -w"
echo "Once available, run: curl http://<EXTERNAL-IP>"

# Cleanup instructions
echo "To clean up: kubectl delete -f nginx.yaml"
