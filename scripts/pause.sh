#!/usr/bin/env bash
# COST SAVER: stop the Jenkins EC2 instance and the RDS instance when you are
# not actively demoing. EKS nodes are the big cost — scale the node group to 0
# to pause compute while keeping the (cheap) control plane.
#
# NOTE: the EKS control plane ($0.10/hr) cannot be stopped, only destroyed.
# For maximum savings between long gaps, use `make destroy` instead.
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform/envs/dev" && pwd)"
REGION="$(terraform -chdir="$TF_DIR" output -raw region)"
CLUSTER="$(terraform -chdir="$TF_DIR" output -raw eks_cluster_name)"
JENKINS_ID="$(terraform -chdir="$TF_DIR" output -raw jenkins_public_ip >/dev/null 2>&1; terraform -chdir="$TF_DIR" state show module.ec2_jenkins.aws_instance.jenkins 2>/dev/null | awk '/^\s*id\s*=/{print $3; exit}' | tr -d '"')"

echo ">> Scaling EKS node group to 0"
NG="$(aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$REGION" --query 'nodegroups[0]' --output text)"
aws eks update-nodegroup-config --cluster-name "$CLUSTER" --nodegroup-name "$NG" \
  --scaling-config minSize=0,maxSize=3,desiredSize=0 --region "$REGION"

echo ">> Stopping Jenkins EC2 ($JENKINS_ID)"
[ -n "$JENKINS_ID" ] && aws ec2 stop-instances --instance-ids "$JENKINS_ID" --region "$REGION" || echo "skip jenkins"

echo ">> Stopping RDS"
DB_ID="$(aws rds describe-db-instances --region "$REGION" --query "DBInstances[?contains(DBInstanceIdentifier, 'mysql')].DBInstanceIdentifier | [0]" --output text)"
[ "$DB_ID" != "None" ] && aws rds stop-db-instance --db-instance-identifier "$DB_ID" --region "$REGION" || echo "skip rds"

echo "Paused. Compute cost is now minimal (control plane + storage only)."
