# Windows self-hosted GitHub Actions runner

This stack deploys a Windows Server 2022 EC2 instance and registers it as a GitHub Actions self-hosted runner for the specified repository.

Runner labels: `self-hosted, windows, x64, windows-containers`

Prerequisites
- A VPC and a public subnet with outbound internet access.
- Create an SSM SecureString parameter with a fine-grained GitHub PAT that can create runner registration tokens for the target repo.
  - Example: name `/github/pat/runner`, value = PAT, KMS key = your CMK (or AWS managed), type = SecureString
  - PAT scopes (fine-grained): Repository permissions -> Administration: Read/Write (for runner registration tokens)
- Ensure your security posture allows outbound HTTPS to `api.github.com` and GitHub release assets.

Example apply

```bash
cd stacks/runners/windows
terraform init
terraform apply -var vpc_id=vpc-xxxxxxxx \
  -var subnet_id=subnet-xxxxxxxx \
  -var github_owner=oscarmartinez0880 \
  -var github_repo=cluckin-bell-app \
  -var github_pat_ssm_parameter_name=/github/pat/runner
```

Notes
- This PR does not install Docker/Windows containers. If you plan to build/push Windows container images on the runner, add Docker installation via SSM Association or extend user data in the module (follow-up PR recommended).
- Consider switching the AMI SSM parameter to the `Windows_Server-2022-English-Full-ContainersLatest` image if you need built-in container support.