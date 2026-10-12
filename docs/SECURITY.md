# Security Practices

This project demonstrates security practices expected in a real DevOps setup.

## Network
- **RDS is private**: no public IP, placed in private subnets, reachable only
  from the EKS node security group and the Jenkins security group (explicit
  SG-to-SG rules, no `0.0.0.0/0`).
- **Jenkins ingress is locked down**: SSH (22) and the UI (8080) are restricted
  to `allowed_ssh_cidr` (your IP /32), not the whole internet.
- **EKS nodes run in private subnets** behind a single NAT gateway.

## Secrets
- **No secrets in Git**: `.gitignore` blocks `.env`, `*.tfvars`, `*.pem`.
- **DB password is generated** by Terraform (`random_password`) and stored in
  **AWS Secrets Manager**, never hardcoded.
- The Kubernetes `db-credentials` Secret is created at deploy time from Secrets
  Manager (see `scripts/deploy.sh`), so credentials never live in the repo.
- **Production upgrade path**: use the External Secrets Operator (ESO) to sync
  Secrets Manager → Kubernetes automatically, and IRSA so pods assume scoped
  IAM roles instead of using static keys.

## IAM — least privilege
- The Jenkins instance role only has: ECR auth, push/pull to the single app
  repo, read the one DB secret, and describe EKS. No `*:*`.
- EKS access for Jenkins is granted via an EKS **access entry**, scoped to the
  cluster, rather than editing `aws-auth` by hand.

## Container & image
- **Multi-stage Dockerfile**, runs as a **non-root** user.
- Pod `securityContext`: `runAsNonRoot`, `readOnlyRootFilesystem`,
  `allowPrivilegeEscalation: false`, all Linux capabilities dropped.
- **ECR image scanning on push** + a **Trivy** gate in the pipeline that fails
  on HIGH/CRITICAL CVEs.
- ECR repo is **immutable** (tags can't be overwritten) and **encrypted**.

## Data
- RDS storage is **encrypted** (`storage_encrypted = true`).
- EBS volumes on EC2/EKS are encrypted.
- TLS to RDS is enabled in the app (`DB_SSL=true` in the Deployment).

## Application
- **Parameterized SQL** everywhere (prevents SQL injection).
- Input validation on write endpoints.
- Centralized error handler that never leaks stack traces to clients.

## State
- Terraform **remote state** in S3 (versioned, encrypted, public access
  blocked) with **DynamoDB locking** — see `scripts/bootstrap-backend.sh`.
- Note: state can contain sensitive values; the S3 bucket is private and
  encrypted for that reason.

## Known trade-offs (documented honestly for interviews)
- `skip_final_snapshot = true` and `deletion_protection = false` on RDS make
  teardown easy for a demo but are unsafe for production.
- Grafana admin password is a placeholder in values; wire it to a Secret for
  real use.
- Single NAT gateway and Single-AZ RDS reduce cost but also reduce HA.
