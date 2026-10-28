# Capstone 02 — Automate Kubernetes Deployment with Terraform & Ansible

**TechWorld with Nana · DevOps Bootcamp · Capstone 02**

> **State:** Consolidated implementation created from existing course project patterns; **not yet deployed or live-validated**. Do not interpret committed source as proof of AWS resources, Kubernetes health, or a passed end-to-end project.

## Architecture

`Terraform → VPC (public/private subnets, NAT) → Amazon EKS + managed nodes → kubeconfig → Ansible → Kubernetes Namespace (my-app) → Nginx Deployment → ClusterIP Service`

**Requirement alignment:** Terraform defines a new EKS cluster; Ansible creates a new namespace and deploys an application to it. Unlike the historical demo, this implementation uses a private-internal service by default. Use `kubectl port-forward` to smoke-test without incurring a public LoadBalancer charge.

## Source attribution

This repository is a consolidated, security-improved implementation based on my earlier exercises:

- [Original Terraform EKS branch](https://github.com/asambataiden/twn-devops-bootcamp-12-terraform-terraform-learn/tree/feature/project-14-ansible-eks-k8s-deploy-to-eks-with-terraform)
- [Original Ansible Kubernetes branch](https://github.com/asambataiden/twn-devops-bootcamp-15-ansible-deploy-node-app/tree/feature/project-14-ansible-inventory-deploy-to-eks-k8s)

It does not claim to have executed the original instructor exercise or reproduced past run evidence in this new repository.

## Layout

- `terraform/`: EKS, VPC and managed node group; pinned module versions, account guard, variable checks
- `ansible/`: namespace and templated Nginx Deployment/ClusterIP Service
- `scripts/verify.sh`: identity checks, workload rollout and image inspection
- `docs/bootcamp-submission.md`: required questions and answers
- `docs/kubeconfig-guidance.md`: safe cluster authentication procedure
- `.github/workflows/static-checks.yml`: lightweight static checks; **not** cloud integration tests

## Prerequisites and cost warning

Terraform >= 1.5.7; AWS provider 6.x and approved AWS profile, Ansible, `kubernetes.core` collection, Python Kubernetes dependencies, AWS CLI v2, kubectl. EKS, NAT gateway, EC2 nodes and network transfer **incur charges**. No Terraform `apply`, Ansible Kubernetes mutation or `destroy` should occur without approving cost, scope and rollback. The original Capstone 01 cluster is a different environment and is **not** substituted here.

## 1 — Inspect and validate before deployment

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit account ID, trusted CIDRs, node sizing, region and cost assumptions
export AWS_PROFILE=YOUR_APPROVED_PROFILE
aws sts get-caller-identity
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -input=false -out=review.tfplan  # inspect sensitive saved plan and cost impact
terraform show review.tfplan
```

`terraform init` resolves modules/plugins; lock provider selections and commit only a reviewed `.terraform.lock.hcl` generated in your environment. Saved plans/state must remain private. **Do not apply until reviewed.** For team use, configure a protected remote backend rather than relying on the default local state; this repository intentionally does not point to the unrelated Capstone 01 state bucket.

## 2 — Deploy only to an approved created cluster

Once an authorized operator has provisioned the intended EKS cluster and verified the exact AWS account, generate a dedicated kubeconfig as described in [kubeconfig guide](docs/kubeconfig-guidance.md). Then:

```bash
cd ansible
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
cp vars.example.yml vars.yml
# Ensure vars.yml uses k8s_namespace (not reserved 'namespace').
# Use the ansible-playbook executable from the intended Python environment.
# Pin the Nginx image to a reviewed image@sha256 digest and edit vars.yml
export KUBECONFIG="$HOME/.kube/capstone02"
export CAP02_APPROVED_CLUSTER=myapp-eks-cluster
ansible-playbook --syntax-check deploy.yml
# Operator approval needed before actual mutation:
ansible-playbook deploy.yml
```

The image is deliberately a placeholder to prevent accidental deployment with mutable `latest`. An image digest must be chosen/verified with the expected architecture. `vars.yml` is environment specific: avoid storing credentials in it.

## 3 — Runtime verification

```bash
export AWS_PROFILE=YOUR_APPROVED_PROFILE
export KUBECONFIG="$HOME/.kube/capstone02"
export CAP02_APPROVED_CLUSTER=myapp-eks-cluster
bash scripts/verify.sh
kubectl -n my-app port-forward svc/nginx-service 18080:80
# In another terminal: curl -fsS http://127.0.0.1:18080/
```

## 4 — Completion criteria

- [x] Source implementation integrated into a dedicated project layout
- [x] Terraform EKS, VPC and managed node definitions present
- [x] Ansible namespace and application deployment defined
- [x] README, security/cost notes and submission answers written
- [x] Terraform initialization, formatting and validation passed locally (28 October 2026); plan remains pending
- [ ] Terraform plan reviewed in approved account
- [ ] Terraform EKS provisioning actually completed (only if authorized and budgeted)
- [ ] Ansible playbook task recap shows success
- [ ] Namespace, Pod readiness, Service and HTTP response validated
- [ ] Evidence and cleanup plan recorded

## Operational notes

- Terraform creates billable cloud resources. It is **not** tied to the existing Capstone 01 cluster.
- Ansible tasks are declarative/idempotent and do not use global SSH host-key bypass.
- Kubernetes public access is narrowed to explicitly configured source CIDRs, but cluster-creator administration is still enabled for laboratory bootstrap.
- This example uses nginx with probes and resource bounds but is **not fully production hardened**: the stock Nginx container may need a custom unprivileged image for non-root/root-filesystem lockdown.
- Dependency versions and runtime compatibility must be checked against the actual Terraform/Ansible/Kubernetes tools before execution.

**Bootcamp submission:** [what I built, what I learned, and repository URL](docs/bootcamp-submission.md).


## Ansible controller compatibility (macOS, October 2026)

Use Python **3.14** with `ansible-core>=2.21,<2.22`. Python 3.15 is not supported by Ansible Core 2.21, and Core 2.19 supports only Python 3.11–3.13 on the control node. Using Python 3.15 with Core 2.19 can fail at startup with `AttributeError: module 'dataclasses' has no attribute '_is_type'`.

From `ansible/`:

```bash
deactivate 2>/dev/null || true
command -v python3.14 || brew install python@3.14
rm -rf .venv
python3.14 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install "ansible-core>=2.21,<2.22" -r requirements.txt
ansible-galaxy collection install -r requirements.yml
python --version
ansible-playbook --version
ansible-playbook -i localhost, --syntax-check deploy.yml
```

**Note:** These commands recreate only the ignored local virtual environment. The existing local `vars.yml` must use `k8s_namespace: my-app`. Syntax checking does not deploy anything to AWS or Kubernetes.
