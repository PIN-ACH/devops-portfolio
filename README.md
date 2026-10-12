# End-to-End DevOps Portfolio Project

A production-style DevOps pipeline on AWS: a **Node.js + MySQL** application
built and tested by **Jenkins** (on a standalone EC2), shipped to **Amazon ECR**,
and deployed to **Amazon EKS** via **GitOps with Argo CD**, backed by **Amazon
RDS (MySQL)**, provisioned entirely with **Terraform**, configured with
**Ansible**, and observed with **Prometheus + Grafana**.

> Built as an interview/portfolio showcase. Optimized to run on a **$200 AWS
> credit** budget (~$0.30/hr running; pause or destroy between demos).

## Architecture

```
Developer push
      │
      ▼
┌──────────────┐   build/test/scan    ┌──────────┐
│  Jenkins EC2 │ ───────────────────▶ │   ECR    │
│ (standalone) │   push image         └────┬─────┘
└──────┬───────┘                           │
       │ commit new image tag              │ pull
       ▼                                   ▼
   Git repo ◀──── watches ──── ┌───────────────────────────┐
                   │           │          EKS              │
              ┌────▼────┐      │  ┌─────────┐ ┌──────────┐ │
              │ Argo CD │ sync │  │ node-app│ │Prometheus│ │
              │ (GitOps)│ ────▶│  └────┬────┘ │ +Grafana │ │
              └─────────┘      │       │      └──────────┘ │
                               └───────┼───────────────────┘
                                       ▼
                               ┌───────────────┐
                               │ RDS (MySQL)   │  (private subnets)
                               └───────────────┘
```

## Tech stack
Terraform · Ansible · Jenkins · Docker · Amazon ECR · Amazon EKS · Amazon RDS
(MySQL) · Argo CD · Prometheus · Grafana · Node.js (Express) · Trivy

## Repository layout
```
app/                 Node.js + MySQL REST API (tests, Dockerfile, migrations)
terraform/           Modular IaC: vpc, ecr, eks, rds, iam, ec2-jenkins
  envs/dev/          Root config wiring the modules together
ansible/             Configures the Jenkins controller (Java, Docker, kubectl…)
Jenkinsfile          CI/CD pipeline (build → test → scan → push → GitOps bump)
k8s/app/             Deployment, Service, HPA, namespace
argocd/              Argo CD Applications (app + monitoring)
monitoring/          kube-prometheus-stack values + custom Grafana dashboard
scripts/             bootstrap, deploy, pause, resume, cleanup
docs/                SECURITY.md, COST.md, PORTFOLIO.md
Makefile             One-liners for the whole lifecycle
```

## Prerequisites
- AWS account + credentials configured (`aws configure`)
- An existing EC2 key pair (for SSH to Jenkins)
- Local tools: `terraform >= 1.5`, `ansible`, `kubectl`, `helm`, `jq`, `aws` CLI
- `node >= 20` (only if you want to run the app/tests locally)

## Quick start

```bash
# 0. (optional but recommended) create remote state backend, then uncomment the
#    backend block in terraform/envs/dev/main.tf
make bootstrap

# 1. configure your values
cp terraform/envs/dev/terraform.tfvars.example terraform/envs/dev/terraform.tfvars
#    edit: key_name, allowed_ssh_cidr (your-ip/32), region

# 2. provision infrastructure (~15–20 min: EKS is the slow part)
make apply

# 3. configure the Jenkins controller
#    put the `jenkins_public_ip` output into ansible/inventory.ini, then:
cd ansible && ansible-playbook playbook.yml && cd ..

# 4. install Argo CD, create the DB secret from Secrets Manager, run migrations
make deploy

# 5. register the GitOps apps (edit argocd/application.yaml REPO_URL first)
kubectl apply -f argocd/application.yaml
kubectl apply -f argocd/monitoring-application.yaml
```

### Run the database migration
```bash
# From a machine that can reach RDS (e.g. the Jenkins box via SSH), with the
# DB_* env vars set from Secrets Manager:
cd app && npm ci && npm run migrate
```

### Access the pieces
```bash
# Jenkins:  http://<jenkins_public_ip>:8080   (initial password:)
ssh ubuntu@<jenkins_public_ip> 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'

# Argo CD:
kubectl -n argocd port-forward svc/argocd-server 8081:443   # https://localhost:8081
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# App (LoadBalancer URL):
kubectl -n app get svc node-app

# Grafana (LoadBalancer URL):
kubectl -n monitoring get svc monitoring-grafana
```

## The CI/CD + GitOps flow
1. Push code → Jenkins triggers (`Jenkinsfile`).
2. Jenkins: `npm ci` → lint → **Jest tests** → `docker build` → **Trivy scan** →
   push to **ECR**.
3. Jenkins bumps the image tag in `k8s/app/deployment.yaml` and pushes the commit.
4. **Argo CD** detects the change and syncs it to **EKS** (self-healing, pruning).
5. **Prometheus** scrapes `/metrics`; **Grafana** shows the dashboard.

## Application API
| Method | Path             | Description                     |
|--------|------------------|---------------------------------|
| GET    | `/healthz`       | Liveness                        |
| GET    | `/readyz`        | Readiness (checks DB)           |
| GET    | `/metrics`       | Prometheus metrics              |
| GET    | `/api/messages`  | List last 100 messages          |
| POST   | `/api/messages`  | Create a message `{ "body" }`   |

## Testing
```bash
make test            # app unit tests (Jest + Supertest), DB is mocked
make validate        # terraform fmt check + validate
```

## Cost & teardown
- **Pause** (same-day gaps): `make pause` — scales EKS nodes to 0, stops
  Jenkins + RDS.
- **Resume**: `make resume`.
- **Destroy everything**: `make destroy` — removes K8s LoadBalancers first, then
  `terraform destroy`.

See [`docs/COST.md`](docs/COST.md) for the full cost breakdown and
[`docs/SECURITY.md`](docs/SECURITY.md) for security practices.
See [`docs/PORTFOLIO.md`](docs/PORTFOLIO.md) for how to present this to recruiters.

## License
MIT
