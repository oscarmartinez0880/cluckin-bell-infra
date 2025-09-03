# Terraform Modules Matrix

This document provides an overview of all available Terraform modules in the `modules/` directory, their purpose, and key variables.

## Infrastructure Modules

### Core Infrastructure

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `vpc` | Creates VPC with public/private subnets, NAT gateways, and VPC endpoints | `name`, `vpc_cidr`, `public_subnet_cidrs`, `private_subnet_cidrs`, `single_nat_gateway` | AWS ~> 5.0 |
| `eks` | Creates EKS cluster with node groups, add-ons, and OIDC provider | `cluster_name`, `cluster_version`, `subnet_ids`, `node_groups` | AWS ~> 5.0 |
| `ecr` | Creates ECR repositories with lifecycle policies and cross-account access | `repository_names`, `image_tag_mutability`, `enable_lifecycle_policy` | AWS ~> 5.0 |
| `rds` | Creates RDS instances with encryption and backup configuration | `db_name`, `engine`, `instance_class`, `allocated_storage` | AWS ~> 5.0 |
| `elasticache` | Creates ElastiCache clusters for Redis/Memcached | `cluster_id`, `engine`, `node_type`, `num_cache_nodes` | AWS ~> 5.0 |
| `efs` | Creates EFS file systems with mount targets and access points | `name`, `vpc_id`, `subnet_ids`, `performance_mode` | AWS ~> 5.0 |

### Security and Identity

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `iam` | Creates IAM roles, policies, and GitHub OIDC provider | `github_repositories`, `additional_role_policies` | AWS ~> 5.0 |
| `irsa` | Creates IRSA roles for Kubernetes service accounts | `role_name`, `oidc_provider_arn`, `namespace`, `service_account` | AWS ~> 5.0 |
| `github-oidc` | Creates GitHub Actions OIDC provider and roles | `role_name`, `github_repo_condition`, `managed_policy_arns` | AWS ~> 5.0 |
| `cognito` | Creates Cognito user pools and clients for authentication | `user_pool_name`, `domain_name`, `clients`, `admin_user_emails` | AWS ~> 5.0 |
| `secrets` | Creates AWS Secrets Manager secrets with generated passwords | `secrets` (map of secret configurations) | AWS ~> 5.0, Random ~> 3.0 |
| `wafv2` | Creates WAF WebACL with managed and custom rules | `name_prefix`, `environment`, `api_rate_limit`, `geo_block_countries` | AWS ~> 5.0 |

### DNS and Certificates

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `dns-certs` | Combined Route53 zones and ACM certificates with DNS validation | `public_zone`, `private_zone`, `certificates`, `subdomain_zones` | AWS ~> 5.0 |

### Kubernetes and Applications

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `k8s-controllers` | Installs essential Kubernetes controllers (ALB, External DNS, etc.) | `cluster_name`, `enable_aws_load_balancer_controller`, `enable_external_dns` | AWS ~> 5.0, Kubernetes ~> 2.20, Helm ~> 2.0 |
| `argocd` | Installs and configures Argo CD with GitHub integration | `cluster_name`, `domain_name`, `github_org`, `github_repo` | AWS ~> 5.0, Kubernetes ~> 2.20, Helm ~> 2.0 |

### Monitoring and Observability

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `monitoring` | Creates CloudWatch resources, dashboards, alarms, and Container Insights | `log_groups`, `metric_alarms`, `dashboards`, `container_insights` | AWS ~> 5.0, Kubernetes ~> 2.20, Helm ~> 2.0 |

### CI/CD and DevOps

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `github-workflow` | Creates GitHub workflow configurations and secrets | `repositories`, `workflow_configs` | AWS ~> 5.0 |
| `gha-windows-runner` | Creates self-hosted GitHub Actions runners on Windows | `runner_name`, `github_token`, `subnet_id` | AWS ~> 5.0 |

### Utilities

| Module | Purpose | Key Variables | Provider Requirements |
|--------|---------|---------------|----------------------|
| `ssm-bastion` | Creates SSM-enabled bastion hosts for secure access | `name`, `vpc_id`, `subnet_id`, `instance_type` | AWS ~> 5.0 |

## Environment Model

The infrastructure supports a two-cluster environment model:

### Nonprod Environment (Account: 264765154707)
- **Cluster Name**: `cluckn-bell-nonprod`
- **Namespaces**: 
  - `dev` - Development environment
  - `qa` - Quality assurance environment

### Prod Environment (Account: 346746763840)
- **Cluster Name**: `cluckn-bell-prod`
- **Namespaces**:
  - `prod` - Production environment

## Terraform and Kubernetes Versions

- **Terraform**: >= 1.13.1
- **Kubernetes**: >= 1.30
- **Provider Versions**:
  - AWS Provider: ~> 5.0
  - Kubernetes Provider: ~> 2.20
  - Helm Provider: ~> 2.0

## Usage Examples

### VPC with Single NAT Gateway (Cost Optimization)
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  name                = "cluckn-bell-nonprod"
  vpc_cidr           = "10.0.0.0/16"
  single_nat_gateway = true
  
  tags = {
    Environment = "nonprod"
  }
}
```

### EKS Cluster with Multiple Node Groups
```hcl
module "eks" {
  source = "./modules/eks"
  
  cluster_name       = "cluckn-bell-nonprod"
  cluster_version    = "1.30"
  subnet_ids         = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      instance_type = "t3.medium"
      min_size      = 1
      max_size      = 3
      desired_size  = 2
      labels = {
        role = "general"
      }
    }
  }
}
```

### Combined DNS and Certificates
```hcl
module "dns_certs" {
  source = "./modules/dns-certs"
  
  public_zone = {
    name   = "cluckn-bell.com"
    create = true
  }
  
  private_zone = {
    name   = "cluckn-bell.com"
    create = true
    vpc_id = module.vpc.vpc_id
  }
  
  certificates = {
    wildcard = {
      domain_name               = "*.cluckn-bell.com"
      subject_alternative_names = ["cluckn-bell.com"]
      use_private_zone         = false
    }
  }
}
```

### Container Insights in Monitoring
```hcl
module "monitoring" {
  source = "./modules/monitoring"
  
  container_insights = {
    enabled                    = true
    cluster_name              = "cluckn-bell-nonprod"
    aws_region                = "us-east-1"
    log_retention_days        = 7
    enable_cloudwatch_agent   = true
    enable_fluent_bit         = true
    cloudwatch_agent_role_arn = module.irsa_cloudwatch.role_arn
    fluent_bit_role_arn       = module.irsa_fluent_bit.role_arn
  }
}
```