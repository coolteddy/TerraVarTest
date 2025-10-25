
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

cat <<YAML > ingress.yaml
# ingress.yaml (example when you have a Service named web:80)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
YAML

kubectl apply -f ingress.yaml
echo "Waiting for EXTERNAL-IP. Use: kubectl get svc web -w"
echo "Once available, run: curl http://<EXTERNAL-IP>"

# Cleanup instructions
echo "To clean up: kubectl delete -f ingress.yaml"
