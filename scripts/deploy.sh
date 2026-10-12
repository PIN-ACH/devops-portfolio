#!/usr/bin/env bash
# Post-apply bootstrap: configure kubectl, install Argo CD, create the DB
# secret from Secrets Manager, run migrations, and register the Argo CD apps.
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform/envs/dev" && pwd)"
REGION="$(terraform -chdir="$TF_DIR" output -raw region)"
CLUSTER="$(terraform -chdir="$TF_DIR" output -raw eks_cluster_name)"
SECRET_ARN="$(terraform -chdir="$TF_DIR" output -raw rds_secret_arn)"

echo ">> Configuring kubectl"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

echo ">> Installing Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

echo ">> Creating DB secret from Secrets Manager"
CREDS="$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)"
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -
kubectl -n app create secret generic db-credentials \
  --from-literal=DB_HOST="$(echo "$CREDS" | jq -r .host)" \
  --from-literal=DB_PORT="$(echo "$CREDS" | jq -r .port)" \
  --from-literal=DB_USER="$(echo "$CREDS" | jq -r .username)" \
  --from-literal=DB_PASSWORD="$(echo "$CREDS" | jq -r .password)" \
  --from-literal=DB_NAME="$(echo "$CREDS" | jq -r .dbname)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ">> Argo CD apps: edit argocd/application.yaml REPO_URL first, then:"
echo "   kubectl apply -f argocd/application.yaml"
echo "   kubectl apply -f argocd/monitoring-application.yaml"

echo ">> Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo ">> Port-forward the UI: kubectl -n argocd port-forward svc/argocd-server 8081:443"
