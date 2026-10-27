# Capstone 02 — Submission Questions and Answers

## What did you build?
I assembled a unified Terraform and Ansible implementation for the TechWorld with Nana **Automate Kubernetes Deployment** assignment. Terraform describes an Amazon EKS cluster, its VPC networking and a managed worker-node group; Ansible uses the Kubernetes API to create a dedicated namespace and deploy an Nginx application behind an internal ClusterIP Service. The repository includes example variables, dependency definitions, verification commands, risk controls and an architecture guide. This is a consolidated, improved implementation using concepts from my earlier course repositories; cloud provisioning and live deployment remain unverified until run evidence is recorded.

## What did you learn?
I learned how to separate infrastructure provisioning from application configuration; use Terraform modules, validated inputs and account protections; create Kubernetes namespaces and workloads idempotently with Ansible collections; handle kubeconfig and IAM credentials without committing them; validate Kubernetes readiness and service health; and evaluate security, repeatability and AWS operating costs. I also learned to distinguish checked-in IaC from successful live execution.

## GitHub URL
Once the new repository is pushed, use:
https://github.com/asambataiden/twn-capstone-02-terraform-ansible-eks

**Important:** Confirm the URL exists and is accessible before submitting; it is a proposed destination until you create and push the repository.
