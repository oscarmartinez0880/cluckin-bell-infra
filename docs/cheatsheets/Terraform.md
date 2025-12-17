# Terraform Cheat Sheet (Infra)

- Initialize (per env)
```bash
make tf-init ENV=nonprod REGION=us-east-1
make tf-init ENV=prod REGION=us-east-1
```

- Plan
```bash
make tf-plan ENV=nonprod REGION=us-east-1
make tf-plan ENV=prod REGION=us-east-1
```

- Apply
```bash
make tf-apply ENV=nonprod REGION=us-east-1
make tf-apply ENV=prod REGION=us-east-1
```

- Destroy (destructive)
```bash
make tf-destroy ENV=nonprod REGION=us-east-1
```

- Outputs
```bash
make outputs ENV=nonprod
make outputs ENV=prod
```

Notes:
- Terraform version: 1.13.1
- DR toggles (prod): enable_ecr_replication, secrets replication, dns failover are disabled by default; see DR.md.
