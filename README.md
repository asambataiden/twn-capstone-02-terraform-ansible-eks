# Capstone 02 — Automate Kubernetes Deployment with Terraform & Ansible

**TechWorld with Nana · AI-Enhanced DevOps Bootcamp · Capstone 02**
**Implementation verified:** 28 October 2026 · **Status:** End-to-end deployment and repeatability verified; teardown still pending.

> This project is a portfolio consolidation and security-focused extension of earlier course exercises. The live validation below comes from a new, dedicated EKS deployment; it does not claim that the original course branches were independently redeployed.

## Project objective

Automate creation of a dedicated Amazon EKS environment with Terraform and deploy an Nginx web server into a new Kubernetes namespace using Ansible. Validate infrastructure, application availability, service access and automation idempotency.

## Architecture

```text
Developer Mac (AWS CLI + Terraform + Ansible)
   │
   ├── Terraform → protected S3 remote state + native lockfile
   │                 └── AWS eu-north-1
   │                      └── Capstone 02 VPC (10.42.0.0/16)
   │                           ├── 2 public subnets + Internet Gateway
   │                           ├── 2 private subnets + NAT Gateway
   │                           └── EKS myapp-eks-cluster (Kubernetes 1.35)
   │                                 └── managed node group: 2 × t3.medium
   │
   └── Dedicated kubeconfig → Ansible (localhost controller)
                                └── namespace my-app
                                     ├── Nginx Deployment (1 replica)
                                     └── nginx-service (ClusterIP :80)
                                           └── local port-forward :18080 → HTTP 200
```

All cloud resources created for this capstone are logically separated from the existing Capstone 01 EKS cluster. The application Service remains internal; smoke testing uses port-forwarding rather than a public load balancer.

## Verified runtime results (28 October 2026)

| Control | Observed result |
|---|---|
| AWS region | `eu-north-1` |
| EKS cluster | `myapp-eks-cluster` — `ACTIVE` |
| Kubernetes API | `v1.35.9-eks-577a51e` |
| VPC ID | `vpc-00377eeb38dd4ae1c` |
| Managed nodes | 2 × `t3.medium`, both `Ready` |
| Terraform recovery apply | `47 added, 0 changed, 0 destroyed` (after 11 resources from initial partial apply were already tracked) |
| Terraform drift detection | `No changes`; `-detailed-exitcode` returned `0` |
| Namespace | `my-app` |
| Ansible initial successful deployment | `ok=8 changed=1 failed=0` |
| Nginx rollout | Deployment `1/1` available; Pod `1/1 Running`, 0 restarts |
| Internal Service | `nginx-service`, `ClusterIP`, port `80` |
| Application smoke test | `curl -fsSI http://127.0.0.1:18080/` → `HTTP/1.1 200 OK` (`nginx/1.28.3`) |
| Ansible repeat run | `ok=8 changed=0 unreachable=0 failed=0` |
| Final image platform | `linux/amd64` confirmed by registry and local Docker inspect |

**Approved immutable image:**

```text
nginx@sha256:6ee8a60426eecd547e15e956742947935ccc66f39811c6ab161d98c6ba6ac148
```

This is a platform-specific OCI manifest verified as `linux/amd64`, matching the EKS nodes. The digest identifies the exact deployed artifact; evaluate current security updates before reusing it in any future deployment.

## Repository structure

- `terraform/` — VPC, EKS, managed node group, providers, variable validation, backend and outputs.
- `terraform/bootstrap-state/` — separate remote-state bucket bootstrap. Its initial local state must be backed up securely and never committed.
- `ansible/` — idempotent namespace, Nginx Deployment and ClusterIP Service, with template and dependency definitions.
- `scripts/verify.sh` — cluster identity, rollout, resource and image checks.
- `docs/terraform-state-and-deployment.md` — backend ownership, deployment validation, risks and teardown safeguards.
- `docs/kubeconfig-guidance.md` — dedicated kubeconfig and identity validation.
- `docs/bootcamp-submission.md` — project answers, troubleshooting and **What I Learned**.
- `.github/workflows/static-checks.yml` — static validation; not proof of live AWS integration.

## Requirements and tooling

Terraform, AWS CLI v2, a scoped AWS identity, Python, `ansible-core`, `kubernetes.core`, the Python Kubernetes client, `kubectl`, Docker Buildx and `jq`.

**Tools observed during validation:** Terraform configuration validated; Kubernetes 1.35.9 API and separately installed `kubectl` v1.35.9; Python 3.14.8; Ansible Core 2.21.5; `kubernetes.core` 6.6.0.

Never commit secrets, kubeconfig files, live `terraform.tfvars`, `.tfstate`, `.tfplan`, private bootstrap state or raw logs containing sensitive identifiers.

## Reproduce safely

### 1. Provision infrastructure (only with AWS cost and scope approval)

```bash
export AWS_PROFILE=asambataiden-dev
export AWS_REGION=eu-north-1
aws sts get-caller-identity

cd terraform
# Review current backend.tf and terraform.tfvars for your own account,
# trusted public-access CIDR, region, cost and state ownership.
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -input=false -out=review.tfplan
terraform show review.tfplan
# Explicitly approve the plan before: terraform apply review.tfplan
```

The existing deployment uses a dedicated S3 backend and locking. **Do not create a second backend or apply a new VPC merely to reproduce the portfolio.** For a new environment, first establish unique state, names and approved quotas. VPC quotas and EKS/EC2/NAT charges matter.

### 2. Select the intended cluster without touching other kubeconfig contexts

```bash
export KUBECONFIG="$HOME/.kube/capstone-02/eks.yaml"
export CAP02_APPROVED_CLUSTER=myapp-eks-cluster
aws eks update-kubeconfig \
  --name myapp-eks-cluster --region eu-north-1 \
  --profile "$AWS_PROFILE" \
  --alias myapp-eks-cluster \
  --user-alias capstone-02-aws
chmod 600 "$KUBECONFIG"
"$HOME/.local/bin/kubectl-1.35" --context myapp-eks-cluster get nodes
```

The published Ansible safety guard checks the context name and the operator approval environment variable. For a stronger production design, additionally verify the actual cluster ARN, AWS account and expected endpoint before mutation.

### 3. Deploy Nginx declaratively

```bash
cd ../ansible
# Install project dependencies according to requirements.txt and requirements.yml.
test -f vars.yml || cp vars.example.yml vars.yml
# Set nginx_image to the verified digest above in ignored local vars.yml.
ansible-playbook -i localhost, --syntax-check deploy.yml
ansible-playbook -i localhost, deploy.yml
```

`vars.yml` must use `k8s_namespace: my-app`, `cluster_name: myapp-eks-cluster` and the approved immutable image digest. The manifest uses resource requests/limits, liveness/readiness probes, a RuntimeDefault seccomp profile and disabled service account token automount. This lab manifest is **not** a complete production security baseline.

### 4. Validate runtime and idempotency

```bash
KUBECTL="$HOME/.local/bin/kubectl-1.35"
"$KUBECTL" --context myapp-eks-cluster -n my-app get deployments,pods,services
"$KUBECTL" --context myapp-eks-cluster -n my-app rollout status deployment/nginx-deployment --timeout=180s
# Terminal 1:
"$KUBECTL" --context myapp-eks-cluster -n my-app port-forward svc/nginx-service 18080:80
# Terminal 2:
curl -fsSI http://127.0.0.1:18080/
# Rerun the unchanged Ansible playbook: changed=0 is expected.
```

## Troubleshooting and engineering decisions

1. **VPC regional quota exceeded (5/5):** Initial Terraform apply partially created 11 IAM/KMS/log resources but could not create the VPC. Inspected account resources and their ownership, requested a quota of 6, preserved remote state and resumed with a refreshed plan. **No unrelated VPC was deleted.**
2. **Transient DNS resolution failure:** A Terraform drift check failed because the local Mac could not resolve the AWS EC2 API hostname. Rechecked DNS, HTTPS and the AWS CLI; after connectivity recovered, Terraform reported no drift.
3. **kubectl version skew:** The Mac had a v1.37 client against an EKS v1.35 server. Installed checksum-verified `kubectl` v1.35.9 alongside the existing executable.
4. **Kubernetes target safety:** Ansible context validation expected `myapp-eks-cluster`, while the initial isolated kubeconfig alias differed. Corrected the alias in the isolated file; verified AWS identity and node readiness.
5. **Invalid container image reference:** An early attempt accidentally used the literal example digest `YOUR_VERIFIED_DIGEST`, creating `InvalidImageName` in an old ReplicaSet.
6. **CPU architecture mismatch:** The next digest selected an `s390x` manifest, causing `exec /docker-entrypoint.sh: exec format error` and `CrashLoopBackOff`. Examined Pod events, container logs and OCI image-index platforms; selected and verified the `linux/amd64` manifest instead.
7. **Ansible repeatability:** An unchanged second deployment showed `changed=0`, demonstrating idempotent reconciliation of the intended Kubernetes resources.

## Security, costs and teardown

- Dedicated VPC and Terraform remote state separate this capstone from Capstone 01.
- EKS public API access was restricted to the approved operator `/32` source at the time of deployment; the location/IP may change. Private endpoint access is enabled.
- EKS audit/API/authenticator logs, KMS encryption and node IMDSv2 requirement were configured.
- Cluster-wide administrator access for the lab operator, unrestricted node egress and a standard Nginx container remain hardening opportunities; they are not proposed as production defaults.
- EKS control-plane, EC2 worker, NAT gateway, public IPv4, KMS and monitoring-related charges can accrue while the lab remains active.
- **Teardown is not yet evidenced.** Before destroying anything, review a destroy plan from `terraform/`, confirm the AWS account, backend key and Capstone 02-only resource addresses, and obtain explicit approval. Keep the separately managed backend and all Capstone 01 resources. Record cleanup evidence afterwards.

## Bootcamp submission

See [Capstone 02 submission questions, answers and detailed learning outcomes](docs/bootcamp-submission.md).

## Source attribution

- [Original Terraform EKS learning branch](https://github.com/asambataiden/twn-devops-bootcamp-12-terraform-terraform-learn/tree/feature/project-14-ansible-eks-k8s-deploy-to-eks-with-terraform)
- [Original Ansible Kubernetes learning branch](https://github.com/asambataiden/twn-devops-bootcamp-15-ansible-deploy-node-app/tree/feature/project-14-ansible-inventory-deploy-to-eks-k8s)

This repository documents the independently verified consolidated Capstone 02 deployment on 28 October 2026.
