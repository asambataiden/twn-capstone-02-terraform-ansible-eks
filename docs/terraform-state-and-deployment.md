# Capstone 02 — Terraform state and deployment decision gate

## Scope

This project provisions a **new** VPC and EKS cluster via Terraform, then uses Ansible to create the `my-app` namespace and deploy Nginx. It does not reuse or adopt Capstone 01 state or infrastructure.

## Pre-deployment prerequisites

- Explicitly approve the AWS account, selected region, name, VPC CIDRs, EKS endpoint access and an estimated total cost.
- Confirm no conflicting cluster, VPC or state bucket already exists.
- Use a scoped AWS role/principal for provisioning where available. The currently configured cluster-creator admin access is a **lab bootstrap exception**, not a production security baseline.
- Choose how to manage backend bootstrap state: the bootstrap Terraform root initially uses **local state**. Store a securely encrypted backup outside Git, test its recovery and do not lose it.
- Verify the S3 state bucket's separate access policy/role before allowing broader team access. Default bucket account permissions alone do not establish least privilege.

## Step A — Optional planned bootstrap (creates billable/persistent S3 resources)

Only with explicit approval:

```bash
cd terraform/bootstrap-state
export AWS_PROFILE=YOUR_APPROVED_PROFILE
terraform init
terraform fmt -check
terraform validate
terraform plan -var='aws_account_id=REPLACE_WITH_APPROVED_ACCOUNT'
# Review, then apply only the approved plan.
```

This root declares a unique bucket, encryption at rest (SSE-S3), versioning, public-access blocking, bucket-owner-enforced object ownership and HTTPS-only access. It has `prevent_destroy` for the bucket. **This is not yet a completed bootstrap**.

## Step B — Activate workload remote state

Only when bucket existence, controls, access and bootstrap-state backup are verified:

1. Copy `terraform/backend.tf.example` to `terraform/backend.tf`; replace the bucket placeholder and review region/key.
2. From `terraform/`, run `terraform init -reconfigure` if no workload state exists. If workload state already exists, use a deliberate `terraform init -migrate-state` workflow instead and back it up first.
3. Verify `terraform state list` targets the intended backend and run `terraform plan` with explicitly reviewed variables.
4. Do not create two competing sources of truth for state. Avoid sharing any Capstone 01 backend key.

S3's native `use_lockfile=true` supports Terraform locking without a DynamoDB table; enable bucket versioning for recovery. Backend access requires state-object read/write and lockfile read/write/delete, plus restricted bucket listing. Use least-privilege IAM in the actual AWS account.

## Step C — Review application plan and runtime validation

The primary Terraform root has already passed `terraform validate` locally, as has Ansible's syntax check. These do **not** prove that the plan is safe or that AWS will accept all resources.

- `terraform plan`: review proposed resource count, IAM privileges, costs, VPC/subnet/AZ suitability, EKS add-on/node capacity and endpoint CIDRs.
- `terraform apply`: only after explicitly approving plan, costs, state ownership, expected resource lifetime and teardown.
- `ansible-playbook`: only after selecting the exact intended cluster, pinning an approved Nginx digest and verifying the execution context.
- `scripts/verify.sh`: capture namespace, rollout and HTTP evidence; confirm the digest deployed matches the selected artifact.
- Cleanup: after assessment, plan approved teardown; retain state and audit evidence. Do not destroy resources shared with other capstones.

## Explicitly deferred as outside this learning assignment

Full multi-account landing zone, GitOps, Vault, service mesh, organization-wide policy and multi-environment HA clusters. These belong in a separate platform project.
