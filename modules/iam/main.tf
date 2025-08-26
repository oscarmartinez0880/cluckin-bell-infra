terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# GitHub OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = var.tags
}

# IAM Role for EKS Service Account (generic IRSA role)
resource "aws_iam_role" "irsa_roles" {
  for_each = var.irsa_roles

  name = "${var.name_prefix}-${each.key}-irsa-role"

  assume_role_policy = templatefile("${path.module}/templates/irsa-trust-policy.json", {
    oidc_arn        = each.value.oidc_provider_arn
    oidc_url        = replace(each.value.oidc_provider_arn, "/^.*\\/([^\\/]+)$/", "$1")
    namespace       = each.value.namespace
    service_account = each.value.service_account
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}-irsa-role"
  })
}

# Attach policies to IRSA roles
resource "aws_iam_role_policy_attachment" "irsa_role_policies" {
  for_each = local.irsa_role_policy_attachments

  role       = aws_iam_role.irsa_roles[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# Custom IAM policies for IRSA roles
resource "aws_iam_role_policy" "irsa_custom_policies" {
  for_each = local.irsa_custom_policies

  name   = "${var.name_prefix}-${each.value.role_key}-${each.value.policy_name}"
  role   = aws_iam_role.irsa_roles[each.value.role_key].id
  policy = each.value.policy_document
}

# Generic IAM roles
resource "aws_iam_role" "roles" {
  for_each = var.iam_roles

  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = each.value.assume_role_policy
  path               = lookup(each.value, "path", "/")

  dynamic "inline_policy" {
    for_each = lookup(each.value, "inline_policies", {})
    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

# Attach managed policies to generic IAM roles
resource "aws_iam_role_policy_attachment" "role_policies" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.roles[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# IAM Users
resource "aws_iam_user" "users" {
  for_each = var.iam_users

  name = "${var.name_prefix}-${each.key}"
  path = lookup(each.value, "path", "/")

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

# Attach policies to users
resource "aws_iam_user_policy_attachment" "user_policies" {
  for_each = local.user_policy_attachments

  user       = aws_iam_user.users[each.value.user_key].name
  policy_arn = each.value.policy_arn
}

# IAM Groups
resource "aws_iam_group" "groups" {
  for_each = var.iam_groups

  name = "${var.name_prefix}-${each.key}"
  path = lookup(each.value, "path", "/")
}

# Attach policies to groups
resource "aws_iam_group_policy_attachment" "group_policies" {
  for_each = local.group_policy_attachments

  group      = aws_iam_group.groups[each.value.group_key].name
  policy_arn = each.value.policy_arn
}

# Add users to groups
resource "aws_iam_group_membership" "group_memberships" {
  for_each = local.group_memberships

  name  = "${var.name_prefix}-${each.key}-membership"
  group = aws_iam_group.groups[each.value.group_key].name
  users = [for user_key in each.value.users : aws_iam_user.users[user_key].name]
}

# Custom IAM policies
resource "aws_iam_policy" "custom_policies" {
  for_each = var.custom_policies

  name        = "${var.name_prefix}-${each.key}"
  path        = lookup(each.value, "path", "/")
  description = lookup(each.value, "description", "Custom policy managed by Terraform")
  policy      = each.value.policy_document

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

# Local values for processing complex data structures
locals {
  # Flatten IRSA role policy attachments
  irsa_role_policy_attachments = merge([
    for role_key, role_config in var.irsa_roles : {
      for policy_arn in lookup(role_config, "policy_arns", []) :
      "${role_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}" => {
        role_key   = role_key
        policy_arn = policy_arn
      }
    }
  ]...)

  # Flatten IRSA custom policies
  irsa_custom_policies = merge([
    for role_key, role_config in var.irsa_roles : {
      for policy_name, policy_document in lookup(role_config, "custom_policies", {}) :
      "${role_key}-${policy_name}" => {
        role_key        = role_key
        policy_name     = policy_name
        policy_document = policy_document
      }
    }
  ]...)

  # Flatten role policy attachments
  role_policy_attachments = merge([
    for role_key, role_config in var.iam_roles : {
      for policy_arn in lookup(role_config, "policy_arns", []) :
      "${role_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}" => {
        role_key   = role_key
        policy_arn = policy_arn
      }
    }
  ]...)

  # Flatten user policy attachments
  user_policy_attachments = merge([
    for user_key, user_config in var.iam_users : {
      for policy_arn in lookup(user_config, "policy_arns", []) :
      "${user_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}" => {
        user_key   = user_key
        policy_arn = policy_arn
      }
    }
  ]...)

  # Flatten group policy attachments
  group_policy_attachments = merge([
    for group_key, group_config in var.iam_groups : {
      for policy_arn in lookup(group_config, "policy_arns", []) :
      "${group_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}" => {
        group_key  = group_key
        policy_arn = policy_arn
      }
    }
  ]...)

  # Flatten group memberships
  group_memberships = {
    for group_key, group_config in var.iam_groups :
    group_key => {
      group_key = group_key
      users     = lookup(group_config, "users", [])
    }
    if length(lookup(group_config, "users", [])) > 0
  }
}