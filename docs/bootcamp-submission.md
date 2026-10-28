# Capstone 02 — Bootcamp Submission: Questions, Answers and Lessons Learned

**Course:** TechWorld with Nana · DevOps Bootcamp
**Project:** Automate Kubernetes Deployment with Terraform and Ansible
**GitHub repository:** https://github.com/asambataiden/twn-capstone-02-terraform-ansible-eks
**Verified implementation date:** 28 October 2026
**Status:** Infrastructure, application deployment, HTTP smoke test and Ansible idempotency verified. AWS teardown remains pending.

## Q1. What did you build?

I built and tested an automated Kubernetes application deployment on Amazon EKS. Terraform provisioned a dedicated VPC with two public and two private subnets, networking components including a NAT gateway, an EKS Kubernetes 1.35 control plane, and a managed EC2 node group with two `t3.medium` workers. Terraform used a separate S3 backend with native state locking to manage the infrastructure state.

After infrastructure provisioning, I used Ansible to connect to the approved EKS cluster via a dedicated kubeconfig. The playbook created the `my-app` namespace, deployed a one-replica Nginx application using a SHA-256-pinned image, created an internal ClusterIP Service, and waited until the deployment was available.

I verified the workload with `kubectl`, tested the Service through port-forwarding and received HTTP `200 OK` from Nginx 1.28.3. I ran the playbook again and confirmed `changed=0`, proving repeatability under the same desired configuration.

## Q2. Which technologies did you use, and why?

| Technology | Purpose |
|---|---|
| Terraform | Declarative AWS provisioning, dependency management and drift detection |
| Amazon VPC | Isolated network with public/private subnet separation |
| Amazon EKS | Managed Kubernetes control plane |
| EKS managed node group / EC2 | Compute capacity for application Pods |
| Amazon S3 Terraform backend | Durable remote state and native lockfile-based concurrency control |
| AWS IAM and KMS | Cluster access roles and encryption controls |
| Ansible + `kubernetes.core` | Repeatable Kubernetes namespace and workload management |
| Kubernetes Deployment/Service | Pod lifecycle, rollout/readiness and internal service discovery |
| Docker Buildx | Inspection of OCI manifest digests and CPU platform compatibility |
| AWS CLI / kubectl / curl | Identity, cluster health, rollout, runtime and HTTP verification |

## Q3. How did you implement the solution?

I separated infrastructure and application management. Terraform owned the AWS VPC, EKS and supporting cloud resources; Ansible owned the Kubernetes namespace, Nginx Deployment and Service. I reviewed a Terraform plan before applying changes, used the existing remote state when recovering from partial provisioning, and verified the resulting infrastructure with a drift-free plan (`exit code 0`).

For application deployment, I created a dedicated kubeconfig instead of overwriting the default Kubernetes configuration. I verified my AWS identity and the selected cluster, exported an explicit approved-cluster name, pinned the Nginx image to a verified `linux/amd64` SHA-256 digest, and ran the Ansible playbook from localhost. Kubernetes probes and the final rollout status confirmed application availability.

The Service was deliberately `ClusterIP` rather than a publicly exposed LoadBalancer. This minimized external exposure and avoided an additional load-balancer charge during testing.

## Q4. What challenges did you encounter, and how did you solve them?

### AWS VPC quota exceeded

The account had reached its regional VPC quota of five. An initial Terraform apply succeeded for 11 supporting resources before VPC creation failed. I inspected existing VPCs rather than deleting resources whose ownership was uncertain, requested a quota increase from five to six, and reran a fresh Terraform plan after the new quota became effective. The remaining 47 resources were provisioned without changing or destroying existing infrastructure. Terraform state preserved the earlier partial deployment.

### Temporary DNS failure during Terraform validation

A `terraform plan` failed because the local machine could not resolve `ec2.eu-north-1.amazonaws.com`. I checked the DNS answer, HTTPS connectivity, AWS API access and my Mac's DNS resolver configuration. When connectivity recovered, Terraform successfully refreshed all resources and returned **No changes**, exit code `0`.

### kubectl version mismatch

The Mac's original `kubectl` client was v1.37 while the EKS server used v1.35. I installed a separate checksum-verified v1.35.9 client and targeted it explicitly, keeping the existing client available for other clusters.

### Ansible target-context alignment

The initial kubeconfig alias did not contain the EKS cluster name expected by the playbook's safety guard. I updated only the dedicated Capstone 02 kubeconfig alias to `myapp-eks-cluster`, verified the AWS account and worker-node readiness, and retained operator confirmation through `CAP02_APPROVED_CLUSTER`.

### Invalid image name and CPU architecture mismatch

The first manifest used a placeholder digest, causing `InvalidImageName`. A subsequent SHA-256 reference resolved to an `s390x` Nginx manifest; it pulled successfully on EKS but exited with `exec /docker-entrypoint.sh: exec format error`, resulting in `CrashLoopBackOff`. I inspected `kubectl describe` events, container logs, the Docker image index and platform metadata. I replaced the image with a verified `linux/amd64` OCI manifest and redeployed through Ansible. The Pod then became `1/1 Running` and the Deployment rolled out successfully.

## Q5. How did you verify the result?

| Verification | Evidence observed |
|---|---|
| Terraform apply | `Apply complete! Resources: 47 added, 0 changed, 0 destroyed` |
| EKS control plane | Cluster `ACTIVE`, Kubernetes `1.35` |
| Managed node group | `ACTIVE`, desired size 2, empty health issues |
| Kubernetes workers | 2/2 nodes `Ready` |
| Terraform drift | `No changes. Your infrastructure matches the configuration.`; exit code `0` |
| Ansible deployment | `ok=8 changed=1 failed=0` after image correction |
| Kubernetes rollout | `deployment "nginx-deployment" successfully rolled out` |
| Nginx runtime | Pod `1/1 Running`, zero restarts; Deployment `1/1` available |
| Nginx HTTP test | `HTTP/1.1 200 OK`, server `nginx/1.28.3` |
| Image architecture | Both registry manifest inspection and local Docker image inspection returned `linux/amd64` |
| Ansible idempotency | `ok=8 changed=0 unreachable=0 failed=0` |

**Final Nginx image:** `nginx@sha256:6ee8a60426eecd547e15e956742947935ccc66f39811c6ab161d98c6ba6ac148`.

The above results are based on terminal outputs captured during the October 28, 2026 deployment. Evidence files should be reviewed for private data before they are published. A completed AWS teardown is **not** claimed.

## Q6. What did you learn?

**Infrastructure and application automation are related, but they have different ownership boundaries.** Terraform is appropriate for provisioning the VPC, EKS control plane, AWS IAM roles and worker-node group. Ansible can then reconcile Kubernetes resources through the API without duplicating infrastructure responsibility. This separation makes the solution easier to review, troubleshoot and maintain.

**Remote Terraform state is essential to safe recovery.** When the first apply stopped after creating some resources, the right response was not to wipe the state or manually delete AWS objects. Terraform's state allowed the next plan to focus on the remaining resources. I also learned the difference between a configuration error, an AWS quota error and a transient DNS resolution failure.

**Kubernetes readiness must be verified at multiple layers.** An EKS cluster being `ACTIVE` does not automatically mean that applications are healthy. I separately checked managed node-group health, node readiness, `kube-system` Pods, the Deployment rollout, Pod events and logs, the Service, and the actual HTTP response. Each layer answers a different operational question.

**Immutable image digests are necessary for reproducibility, but not sufficient for portability.** I initially used an immutable Nginx image manifest for the wrong CPU architecture. The registry was reachable and Kubernetes could pull the image, yet the executable failed on AMD64 worker nodes. I learned to distinguish an OCI multi-platform index from a specific platform manifest, examine `linux/amd64` and other platforms, and verify the actual selected artifact before deployment.

**Logs and events provide faster answers than repeated redeployment.** The `InvalidImageName` status explained the placeholder problem, while `exec format error` explained the architecture problem. I learned to read Pod events and container logs before modifying infrastructure or rerunning Ansible blindly.

**Idempotency is a testable property, not just a description of a tool.** A successful first deployment did not demonstrate repeatability by itself. After the Nginx Pod and Service became healthy, I ran the unchanged Ansible playbook again and observed `changed=0`, confirming that the playbook converged on the desired state.

**Cluster context isolation matters when operating multiple environments.** I learned to use a dedicated kubeconfig and explicit AWS profile, verify the intended EKS target, and require an approval variable before mutations. I also identified a future improvement: validate the real cluster ARN and AWS account in the automation rather than relying only on the kubeconfig context label.

**Security and cost controls should be designed into a learning project.** I used private worker-node subnets, restricted control-plane public access, KMS-backed protection, audit logs, IMDSv2, internal ClusterIP exposure, image pinning and bounded container resources. I also saw the operational costs and tradeoffs of an EKS control plane and NAT gateway, and the importance of retaining evidence before destroying the temporary lab.

**Most importantly:** the project taught me how to approach a failure systematically: determine whether it affects AWS provisioning, local connectivity, cluster authentication, scheduling, image compatibility or application health; collect evidence; correct the right layer; and prove the result with repeatable checks.

## Q7. What would you improve for production?

- Use short-lived federated AWS roles and least-privilege Kubernetes access rather than a lab administrator principal.
- Validate AWS account ID, cluster ARN, endpoint and kubeconfig identity before applying Ansible changes.
- Add application-level non-root execution and read-only root filesystem support, possibly through a purpose-built unprivileged Nginx image.
- Scope node egress and workload network policies where appropriate.
- Pin and review dependency/image versions with vulnerability and supply-chain scanning.
- Add CI checks for Terraform plans, manifest validation, image architecture and Ansible idempotency in an isolated test environment.
- Capture standardized evidence and confirm teardown removes only resources owned by this capstone.

## GitHub URL

https://github.com/asambataiden/twn-capstone-02-terraform-ansible-eks

**Submission state:** The infrastructure and Nginx workload have been deployed and validated. Repository documentation/evidence synchronization and controlled lab cleanup are separate final tasks.
