# Portfolio Presentation Guide

Your infrastructure is ephemeral, but your **GitHub repository is permanent** —
that's what recruiters and interviewers actually review. Make it tell the story.

## 1. Capture evidence while it's running
During a live session (`make apply` + `make deploy`), capture:
- [ ] Screenshot: `terraform apply` summary (resources created)
- [ ] Screenshot: Jenkins pipeline — all stages green
- [ ] Screenshot: Argo CD UI showing `node-app` and `monitoring` Synced/Healthy
- [ ] Screenshot: Grafana "Node App Overview" dashboard with live traffic
- [ ] Screenshot: `kubectl get pods -A` showing app + argocd + monitoring
- [ ] Short screen recording (2–3 min): push a commit → Jenkins builds →
      Argo CD syncs → new version live. This is the money shot.

Save these under `docs/screenshots/` and embed them in the README.

## 2. Generate some traffic for the dashboard
```bash
APP_URL=$(kubectl -n app get svc node-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in $(seq 1 200); do
  curl -s -X POST "http://$APP_URL/api/messages" -H 'Content-Type: application/json' -d '{"body":"hello '$i'"}' >/dev/null
  curl -s "http://$APP_URL/api/messages" >/dev/null
done
```

## 3. Talking points for interviews
- **Why standalone Jenkins EC2?** Decouples CI from the cluster; shows you can
  integrate an external CI with EKS via IAM + ECR + GitOps.
- **Why GitOps (Argo CD) instead of `kubectl apply` from Jenkins?** Declarative,
  auditable, self-healing, and the cluster pulls rather than CI pushing creds in.
- **How do secrets flow?** Terraform → Secrets Manager → (deploy script) →
  K8s Secret → pod env. No secret in Git. Mention ESO as the production upgrade.
- **How do you control cost?** Spot nodes, single NAT, pause/destroy workflow,
  Budgets alerts. Quote the ~$0.30/hr figure.
- **Security?** Walk through `docs/SECURITY.md`: private RDS, least-privilege
  IAM, non-root containers, Trivy gate, encrypted storage.

## 4. README should have, in order
1. Architecture diagram (ASCII one in README is fine, or export a drawn one)
2. Tech stack badges
3. The GitOps flow explained in 3 lines
4. Screenshots
5. "How to run" + "How to tear down"
6. Security & cost sections linked
