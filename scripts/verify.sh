#!/usr/bin/env bash
set -euo pipefail
: "${AWS_PROFILE:?Set AWS_PROFILE}" "${KUBECONFIG:?Set KUBECONFIG}" "${CAP02_APPROVED_CLUSTER:?Set CAP02_APPROVED_CLUSTER}"
NAMESPACE="${CAP02_NAMESPACE:-my-app}"
echo 'AWS identity:'
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json
echo 'Kubeconfig context:'
kubectl config current-context
CONTEXT="$(kubectl config current-context)"
case "$CONTEXT" in
  *"$CAP02_APPROVED_CLUSTER"*) ;;
  *) echo "Context does not contain approved cluster name" >&2; exit 1 ;;
esac
kubectl -n "$NAMESPACE" get deployments,pods,services
kubectl -n "$NAMESPACE" rollout status deployment/nginx-deployment --timeout=180s
kubectl -n "$NAMESPACE" get deployment nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
printf '\n'
echo 'For HTTP smoke test, run: kubectl -n my-app port-forward svc/nginx-service 18080:80 and curl -fsS http://127.0.0.1:18080/'
