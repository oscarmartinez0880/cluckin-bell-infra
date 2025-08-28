# Prod account hosts apex zone and delegates dev/qa to devqa account

provider "aws" {
  alias  = "prod"
  region = "us-east-1"
}

provider "aws" {
  alias  = "devqa"
  region = "us-east-1"
}

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

output "prod_apex_zone_id" { value = aws_route53_zone.apex.zone_id }
output "dev_zone_id"       { value = aws_route53_zone.dev.zone_id }
output "qa_zone_id"        { value = aws_route53_zone.qa.zone_id }