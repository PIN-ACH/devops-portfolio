#!/usr/bin/env bash
# FULL TEARDOWN — destroys all AWS resources to stop every charge.
# Order matters: delete Kubernetes LoadBalancer services first so their ELBs
# are removed, otherwise `terraform destroy` can hang on the VPC.
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform/envs/dev" && pwd)"

echo ">> Removing Kubernetes LoadBalancer services (frees ELBs)"
if kubectl config current-context >/dev/null 2>&1; then
  kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true || true
  echo ">> Waiting 60s for cloud load balancers to deprovision..."
  sleep 60
else
  echo "   kubectl not configured; skipping (make sure no stray ELBs remain)."
fi

echo ">> terraform destroy"
terraform -chdir="$TF_DIR" destroy -auto-approve

echo
echo ">> Done. Verify nothing lingers:"
echo "   aws ec2 describe-instances --filters Name=tag:Project,Values=devops-portfolio --query 'Reservations[].Instances[].State.Name'"
echo "   aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'"
echo "   Check the AWS Billing console the next day to confirm \$0 running cost."
