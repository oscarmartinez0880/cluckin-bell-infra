# tfvars usage and SSO setup

## Profiles
- Dev/QA account (264765154707): `cluckin-bell-qa`
- Prod account (346746763840): `cluckin-bell-prod`

## Login
```bash
aws sso login --profile cluckin-bell-qa
aws sso login --profile cluckin-bell-prod
```

## Dev/QA (shared cluster) from envs/nonprod
```bash
AWS_PROFILE=cluckin-bell-qa terraform init
AWS_PROFILE=cluckin-bell-qa terraform plan  -var-file=../../tfvars/devqa.tfvars
AWS_PROFILE=cluckin-bell-qa terraform apply -var-file=../../tfvars/devqa.tfvars
```

## Prod from envs/prod
```bash
AWS_PROFILE=cluckin-bell-prod terraform init
AWS_PROFILE=cluckin-bell-prod terraform plan  -var-file=../../tfvars/prod.tfvars
AWS_PROFILE=cluckin-bell-prod terraform apply -var-file=../../tfvars/prod.tfvars
```

## First-time bootstrap (two-phase)
```bash
terraform apply -target=module.eks -var-file=../../tfvars/devqa.tfvars
```

## Finding your SSO IAM role ARN from STS ARN

1) After SSO login, get STS ARN:
```bash
AWS_PROFILE=cluckin-bell-qa   aws sts get-caller-identity --query Arn --output text
AWS_PROFILE=cluckin-bell-prod aws sts get-caller-identity --query Arn --output text
```
You'll see: `arn:aws:sts::<ACCOUNT_ID>:assumed-role/AWSReservedSSO_AdminAccess-Bootstrap_<GUID>/...`

2) Convert to IAM Role ARN:
```
arn:aws:iam::<ACCOUNT_ID>:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess-Bootstrap_<GUID>
```

Set that value in `sso_admin_role_arn` in the tfvars.