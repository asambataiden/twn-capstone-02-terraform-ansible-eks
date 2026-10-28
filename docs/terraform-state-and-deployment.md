# Capstone 02 — Terraform remote state, deployment and cleanup runbook

**Verified state:** Infrastructure was deployed and validated on 28 October 2026. **Teardown has not been performed or verified.**

## 1. Resource boundaries

This Terraform root owns the separate Capstone 02 VPC and EKS stack in `eu-north-1`:

- EKS: `myapp-eks-cluster`
- VPC: `vpc-00377eeb38dd4ae1c`
- Tag marker: `Project=twn-capstone-02`
- AWS account observed during deployment: `591132357918`

**Never treat the Capstone 01 EKS cluster `floral-mongoose-1792497995`, its VPC, any unrelated VPC or other bootcamp environments as part of this root.**

## 2. State backend ownership

The primary Terraform root uses a dedicated S3 remote backend with native locking:

```text
Bucket: twn-capstone02-tfstate-591132357918-eu-north-1
Key:    capstone02/eks/terraform.tfstate
Region: eu-north-1
Lock:   use_lockfile = true
```

The separately created `terraform/bootstrap-state/` Terraform root owns the backend bucket and has its **own bootstrap state**. The bucket's controls were validated: versioning, default encryption, block public access and HTTPS-only access. Do not delete the bucket or bootstrap root when destroying the EKS workload.

The bootstrap state's secure backup remains an operator task unless separately evidenced. Do not put state snapshots or saved Terraform plans in Git.

## 3. What happened during provisioning

1. Initial Terraform validation passed, but `terraform apply` hit AWS regional `VpcLimitExceeded` at five existing VPCs.
2. Terraform correctly recorded 11 supporting resources created before the failed VPC operation.
3. A quota increase to six VPCs became effective; no existing VPC was deleted.
4. A refreshed plan showed `47 to add, 0 to change, 0 to destroy`.
5. Recovery apply completed with `47 added, 0 changed, 0 destroyed`.
6. AWS CLI confirmed EKS `ACTIVE`, managed node group `ACTIVE` and two healthy workers.
7. A subsequent Terraform `-detailed-exitcode` plan returned `0`: **No changes**.
8. Nginx deployment was then applied by Ansible and validated separately; the application remains outside the Terraform root's resource ownership.

This illustrates safe partial-apply recovery: preserve state, resolve the underlying quota, review the revised plan and apply only intended remaining objects.

## 4. Preflight checks before any future Terraform action

Run from the **repository's `terraform/` directory**; never from its parent directory:

```bash
export AWS_PROFILE=asambataiden-dev
export AWS_REGION=eu-north-1
aws sts get-caller-identity
pwd
ls -1 *.tf
terraform init
terraform workspace show
terraform state list
terraform plan -input=false -detailed-exitcode
printf 'Terraform exit code: %s\n' "$?"
```

For drift checks, exit code `0` means no changes, `2` means changes require review and `1` means an error. Do not mistake a DNS failure or running from the wrong directory for a real drift assessment. Review the backend configuration and state resource list before any mutation.

## 5. Preserving submission evidence

Store reviewed, redacted proof of:

- Terraform apply completion and clean drift result;
- EKS and managed node group ACTIVE, two nodes Ready;
- Ansible success recap and unchanged rerun (`changed=0`);
- Pod/Deployment readiness, ClusterIP Service and port-forwarded HTTP 200;
- Image digest and verified `linux/amd64` platform.

Keep raw logs containing account numbers, personal IAM principal names, endpoints or infrastructure identifiers private unless reviewed for publication. Evidence creation does not imply successful teardown.

## 6. Safe workload teardown (future action; requires deliberate approval)

Stop the port-forward and complete all evidence collection first. Ansible-created Kubernetes resources may be removed along with the cluster, but record their status beforehand.

```bash
export AWS_PROFILE=asambataiden-dev
export AWS_REGION=eu-north-1
cd terraform
aws sts get-caller-identity
terraform init
terraform workspace show
terraform state list
terraform plan -destroy -input=false -out=cap02-destroy.tfplan
terraform show cap02-destroy.tfplan
```

**Mandatory manual review:** The planned deletions must belong only to the Capstone 02 Terraform root; confirm the AWS account and backend key. In particular, **the Capstone 01 cluster and its VPC must not appear in the plan**. The state bucket created by `bootstrap-state/` is outside this stack and must also remain untouched. If any resource ownership is ambiguous, do not proceed.

Once the destroy plan is reviewed and explicitly approved, the authorized operator may run `terraform apply cap02-destroy.tfplan`. This command is intentionally **not** represented as already executed. Then verify the target EKS cluster, VPC, NAT and EC2 nodes were removed and record any remaining billable resources, state retention, and final Terraform state. Saved plan files must be kept out of Git.

Some resources, notably KMS keys, can have delayed deletion schedules. Teardown verification must consider such asynchronous lifecycle behavior rather than treating an apply recap as proof every charge stopped immediately.

## 7. Operational risks and production differences

This is a controlled learning environment, not a production baseline. IAM admin access for the operator is a lab exception; prefer federation and least privilege. The node security group permits broad egress. The standard Nginx image is not fully non-root/read-only-rootfs hardened. Cost control remains important: EKS, EC2, NAT, public IPv4, KMS and logs can incur charges.

Keep the S3 backend and its bootstrap state isolated so the infrastructure can be audited without adopting or accidentally changing other project resources.

## Verified Decommissioning — 28 October 2026

The Terraform-managed Capstone 02 environment was successfully
decommissioned after application validation and evidence collection.

| Verification | Result |
|---|---|
| Destroy plan | 0 add, 0 change, 58 destroy |
| Terraform apply | 58 destroyed, 0 failures |
| Remaining managed resources | 0 |
| EKS cluster | Confirmed absent |
| Dedicated VPC | Confirmed absent |
| Managed node group | Destroyed |
| NAT Gateway | Destroyed |
| KMS key | PendingDeletion |
| KMS scheduled deletion | 27 November 2026 |
| S3 state backend | Retained separately |

### Scope and ownership

The destroy plan targeted the resources managed by the
Capstone 02 Terraform workload root, including the dedicated
EKS cluster and VPC.

The separate Terraform state backend was outside that root.
Capstone 01 infrastructure was not included in the destroy plan.

### Recovery and reproducibility

The infrastructure can be recreated using the version-controlled
Terraform and Ansible configuration, provided that all prerequisite
AWS permissions, state-backend configuration, variables, dependencies,
and resource quotas are validated again.

Recreation is not an automatic rollback: a new deployment may
produce different physical resource IDs.

### Evidence

See [Infrastructure cleanup evidence](../evidence/cleanup-public.md).
