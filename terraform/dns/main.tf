###############################################################################
# Terraform and Provider Configuration
###############################################################################
terraform {
  required_version = "~> 1.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

###############################################################################
# AWS Providers
# - cluckin-bell-prod (prod account) hosts apex zone
# - cluckin-bell-qa (dev/qa account) hosts delegated sub-zones
###############################################################################
provider "aws" {
  alias   = "prod"
  region  = var.region
  profile = var.prod_profile
}

provider "aws" {
  alias   = "devqa"
  region  = var.region
  profile = var.devqa_profile
}

###############################################################################
# Route53 Zones
###############################################################################

# Apex zone in prod
resource "aws_route53_zone" "apex" {
  provider = aws.prod
  name     = "cluckn-bell.com"
  comment  = "Cluckn Bell apex zone (Prod account)"
}

# Sub-zones in dev/qa account
resource "aws_route53_zone" "dev" {
  provider = aws.devqa
  name     = "dev.cluckn-bell.com"
}

resource "aws_route53_zone" "qa" {
  provider = aws.devqa
  name     = "qa.cluckn-bell.com"
}

# Delegate dev and qa from apex (prod) to dev/qa account
resource "aws_route53_record" "delegate_dev" {
  provider = aws.prod
  zone_id  = aws_route53_zone.apex.zone_id
  name     = "dev.cluckn-bell.com"
  type     = "NS"
  ttl      = 300
  records  = aws_route53_zone.dev.name_servers
}

resource "aws_route53_record" "delegate_qa" {
  provider = aws.prod
  zone_id  = aws_route53_zone.apex.zone_id
  name     = "qa.cluckn-bell.com"
  type     = "NS"
  ttl      = 300
  records  = aws_route53_zone.qa.name_servers
}

###############################################################################
# Outputs
###############################################################################
output "prod_apex_zone_id" {
  description = "Hosted Zone ID for cluckn-bell.com in prod"
  value       = aws_route53_zone.apex.zone_id
}

output "dev_zone_id" {
  description = "Hosted Zone ID for dev.cluckn-bell.com in dev/qa"
  value       = aws_route53_zone.dev.zone_id
}

output "qa_zone_id" {
  description = "Hosted Zone ID for qa.cluckn-bell.com in dev/qa"
  value       = aws_route53_zone.qa.zone_id
}

###############################################################################
# Variables
###############################################################################
variable "region" {
  description = "AWS Region for Route53 operations"
  type        = string
  default     = "us-east-1"
}

variable "prod_profile" {
  description = "AWS CLI profile for cluckin-bell-prod account (346746763840)"
  type        = string
  default     = "cluckin-bell-prod"
}

variable "devqa_profile" {
  description = "AWS CLI profile for cluckin-bell-qa account (264765154707)"
  type        = string
  default     = "cluckin-bell-qa"
}