# Manage NAT + private egress only when reusing an existing VPC
locals {
  manage_nat_now = local.use_existing_vpc && var.manage_nat_for_existing_vpc
  nat_host_subnet_id = var.nat_public_subnet_id != "" ? var.nat_public_subnet_id : (
    length(local.public_subnet_ids) > 0 ? local.public_subnet_ids[0] : ""
  )
}

# Safety: only proceed if we have a public subnet to host the NAT
resource "aws_eip" "nat" {
  count  = local.manage_nat_now && local.nat_host_subnet_id != "" ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${local.cluster_name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  count         = local.manage_nat_now && local.nat_host_subnet_id != "" ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = local.nat_host_subnet_id

  tags = merge(local.common_tags, { Name = "${local.cluster_name}-nat" })
}

# Find each private subnet's route table
data "aws_route_table" "private_rt" {
  for_each = local.manage_nat_now ? toset(local.private_subnet_ids) : []

  # Look up the route table associated with this subnet
  subnet_id = each.key
}

# Ensure 0.0.0.0/0 goes to our NAT (replaces blackhole routes)
resource "aws_route" "private_default_to_nat" {
  for_each = local.manage_nat_now ? data.aws_route_table.private_rt : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id

  depends_on = [aws_nat_gateway.this]
}

output "nat_gateway_id" {
  value       = try(aws_nat_gateway.this[0].id, null)
  description = "NAT Gateway ID used for private egress when reusing VPC"
}