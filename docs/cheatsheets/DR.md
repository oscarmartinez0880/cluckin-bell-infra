# DR Cheat Sheet

Goal: Stand up prod infra and cluster in an alternate region (e.g., us-west-2) with minimal commands.

- One-click (GitHub Actions):
  - Actions → DR: Launch Prod in Alternate Region
  - Input: region = us-west-2

- Makefile (local):
```bash
make login-prod
make dr-provision-prod REGION=us-west-2
```

- Optional DR features (prod; disabled by default):
  - ECR replication:
    - enable_ecr_replication = true
    - ecr_replication_regions = ["us-west-2"]
  - Secrets replication:
    - enable_secrets_replication = true
    - secrets_replication_regions = ["us-west-2"]
  - DNS failover:
    - enable_dns_failover = true
    - failover_records = { ... }

Validate after provisioning:
- Cluster Ready, core add-ons healthy
- Argo CD syncing applications
- External DNS records present (if enabled)
