# NEW FILE: Dedicated IAM role for all nonprod (dev & qa) managed node groups #
data "aws_iam_policy_document" "eks_node_group_assume" { #
  statement { #
    effect = "Allow" #
    principals { #
      type        = "Service" #
      identifiers = ["ec2.amazonaws.com"] #
    } #
    actions = ["sts:AssumeRole"] #
  } #
} #

resource "aws_iam_role" "eks_node_group" { #
  name               = "${local.cluster_name}-node-group-role" #
  assume_role_policy = data.aws_iam_policy_document.eks_node_group_assume.json #
  tags = merge(local.common_tags, { #
    Component = "node-group-role" #
  }) #
} #

resource "aws_iam_role_policy_attachment" "eks_worker" { #
  role       = aws_iam_role.eks_node_group.name #
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" #
} #

resource "aws_iam_role_policy_attachment" "cni" { #
  role       = aws_iam_role.eks_node_group.name #
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" #
} #

resource "aws_iam_role_policy_attachment" "ecr_read" { #
  role       = aws_iam_role.eks_node_group.name #
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" #
} #

resource "aws_iam_role_policy_attachment" "ssm" { #
  role       = aws_iam_role.eks_node_group.name #
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" #
} #

# Optional (commented) CloudWatch agent server policy #
# resource "aws_iam_role_policy_attachment" "cw_agent" { #
#   role       = aws_iam_role.eks_node_group.name #
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" #
# } #

output "eks_node_group_role_arn" { #
  value = aws_iam_role.eks_node_group.arn #
} #