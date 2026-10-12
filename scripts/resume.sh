#!/usr/bin/env bash
# Resume compute after a pause.
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform/envs/dev" && pwd)"
REGION="$(terraform -chdir="$TF_DIR" output -raw region)"
CLUSTER="$(terraform -chdir="$TF_DIR" output -raw eks_cluster_name)"
JENKINS_ID="$(terraform -chdir="$TF_DIR" state show module.ec2_jenkins.aws_instance.jenkins 2>/dev/null | awk '/^\s*id\s*=/{print $3; exit}' | tr -d '"')"

NG="$(aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$REGION" --query 'nodegroups[0]' --output text)"
echo ">> Scaling EKS node group back to 2"
aws eks update-nodegroup-config --cluster-name "$CLUSTER" --nodegroup-name "$NG" \
  --scaling-config minSize=1,maxSize=3,desiredSize=2 --region "$REGION"

echo ">> Starting Jenkins EC2"
[ -n "$JENKINS_ID" ] && aws ec2 start-instances --instance-ids "$JENKINS_ID" --region "$REGION" || true

echo ">> Starting RDS"
DB_ID="$(aws rds describe-db-instances --region "$REGION" --query "DBInstances[?contains(DBInstanceIdentifier, 'mysql')].DBInstanceIdentifier | [0]" --output text)"
[ "$DB_ID" != "None" ] && aws rds start-db-instance --db-instance-identifier "$DB_ID" --region "$REGION" || true

echo "Resumed. Give nodes ~3-5 min to join and pods to schedule."
