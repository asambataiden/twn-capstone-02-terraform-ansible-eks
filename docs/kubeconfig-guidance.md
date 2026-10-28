# Capstone 02 — Kubeconfig and AWS identity controls

## Verified lab configuration (28 October 2026)

- AWS profile: `asambataiden-dev`
- Region: `eu-north-1`
- EKS cluster: `myapp-eks-cluster`
- Kubernetes context alias: `myapp-eks-cluster`
- Isolated kubeconfig: `$HOME/.kube/capstone-02/eks.yaml`
- Compatible Kubernetes client: `kubectl` v1.35.9

Never commit kubeconfig, AWS credentials or Terraform state. Keep kubeconfig file mode `600` and its parent directory mode `700`.

```bash
export AWS_PROFILE=asambataiden-dev
export AWS_REGION=eu-north-1
export KUBECONFIG="$HOME/.kube/capstone-02/eks.yaml"
export CAP02_APPROVED_CLUSTER=myapp-eks-cluster

aws sts get-caller-identity
aws eks update-kubeconfig \
  --name "$CAP02_APPROVED_CLUSTER" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --alias myapp-eks-cluster \
  --user-alias capstone-02-aws
chmod 600 "$KUBECONFIG"
"$HOME/.local/bin/kubectl-1.35" --context myapp-eks-cluster config current-context
"$HOME/.local/bin/kubectl-1.35" --context myapp-eks-cluster get nodes
```

The cluster was verified as `ACTIVE` and had two `Ready` nodes. Using a dedicated kubeconfig avoids changing the active context of Capstone 01 and other Kubernetes environments.

**Security caveat:** The current playbook checks context text and explicit operator confirmation but not the full cluster ARN/account binding. A context name is not cryptographic identity proof. Harden this preflight before using the approach in client or production environments. Control-plane public access is limited to the explicitly configured source CIDR, which must be revised if the operator's public IP changes. Prefer federated, scoped roles and private API endpoints as appropriate for production.
