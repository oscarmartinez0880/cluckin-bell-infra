# eksctl Cheat Sheet

Cluster lifecycle is managed with eksctl.

- Create
```bash
make eks-create ENV=nonprod REGION=us-east-1
make eks-create ENV=prod REGION=us-east-1
```

- Upgrade
```bash
make eks-upgrade ENV=nonprod
make eks-upgrade ENV=prod
```

- Delete
```bash
make eks-delete ENV=nonprod
make eks-delete ENV=prod
```

Important:
- Update VPC and private subnet IDs in:
  - eksctl/devqa-cluster.yaml
  - eksctl/prod-cluster.yaml
- Kubernetes version is pinned to "1.33".
- Add-ons include: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent.
