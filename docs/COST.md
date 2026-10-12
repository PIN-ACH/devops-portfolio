# Cost Management ($200 credit budget)

The whole point of this setup is to run **only when demoing** and tear down (or
pause) otherwise.

## Running cost (us-east-1, approximate)

| Resource            | Running 24/7 | Paused (`make pause`) |
|---------------------|--------------|------------------------|
| EKS control plane   | ~$73/mo      | ~$73/mo (can't stop)   |
| 2× t3.medium (SPOT) | ~$20/mo      | $0 (scaled to 0)       |
| Jenkins t3.medium   | ~$30/mo      | ~$3/mo (EBS only)      |
| RDS db.t3.micro     | ~$15/mo      | ~$2/mo (storage only)  |
| NAT gateway         | ~$32/mo      | ~$32/mo                |
| **Hourly, running** | **~$0.30/hr**| —                      |

## Strategy

1. **Short sessions**: `make apply` → demo/record → `make destroy`.
   A 3-hour session ≈ **$1**. $200 ≈ **~600 working hours**.
2. **Between same-day sessions**: `make pause` (scales nodes to 0, stops
   Jenkins + RDS). The control plane and NAT still cost ~$0.14/hr.
3. **For gaps longer than a day**: prefer `make destroy`. Rebuild takes
   ~20 min. Your **GitHub repo is the portfolio**, so nothing is lost.

## Watch out for
- **Orphaned ELBs**: `cleanup.sh` deletes LoadBalancer services first so their
  ELBs are removed before `terraform destroy`. Always verify afterwards.
- **NAT gateway** is the sneakiest cost. If you destroy, it's gone; if you only
  pause, it keeps charging.
- Set an **AWS Budgets alert** at $50 and $150 (console → Billing → Budgets).

## Verify zero cost after teardown
```bash
aws ec2 describe-instances --filters Name=tag:Project,Values=devops-portfolio \
  --query 'Reservations[].Instances[].State.Name'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
```
Check the Billing console the next day — cost explorer updates with a delay.
