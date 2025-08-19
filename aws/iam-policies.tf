# IAM Policies for Profile Board Infrastructure
# This file creates and attaches all necessary IAM policies to the specified user

# Variables
variable "iam_user_arn" {
  description = "ARN of the IAM user to attach policies to"
  type        = string
  default     = "arn:aws:iam::085366697881:user/YOUR_USERNAME"
}

# Extract username from ARN
locals {
  username = split("/", var.iam_user_arn)[1]
}

# IAM Policy 1: EC2 and VPC Management
resource "aws_iam_policy" "profile_board_ec2_vpc" {
  name        = "ProfileBoard-EC2-VPC"
  path        = "/"
  description = "IAM policy for EC2, VPC, Security Groups, NAT Gateway, and Elastic IP management"

  policy = file("${path.module}/iam-ec2-vpc.json")

  lifecycle {
    ignore_changes = [policy]
  }

  tags = {
    Name        = "ProfileBoard-EC2-VPC"
    Environment = "Infrastructure"
    Project     = "ProfileBoard"
  }
}

# IAM Policy 2: API Gateway and Load Balancer Management
resource "aws_iam_policy" "profile_board_api_elb" {
  name        = "ProfileBoard-API-ELB"
  path        = "/"
  description = "IAM policy for API Gateway and Elastic Load Balancer management"

  policy = file("${path.module}/iam-api-elb.json")

  lifecycle {
    ignore_changes = [policy]
  }

  tags = {
    Name        = "ProfileBoard-API-ELB"
    Environment = "Infrastructure"
    Project     = "ProfileBoard"
  }
}

# IAM Policy 3: RDS, ECR, and CloudWatch Management
resource "aws_iam_policy" "profile_board_rds_ecr" {
  name        = "ProfileBoard-RDS-ECR"
  path        = "/"
  description = "IAM policy for RDS, ECR, and CloudWatch management"

  policy = file("${path.module}/iam-rds-ecr.json")

  lifecycle {
    ignore_changes = [policy]
  }

  tags = {
    Name        = "ProfileBoard-RDS-ECR"
    Environment = "Infrastructure"
    Project     = "ProfileBoard"
  }
}

# IAM Policy 4: IAM and STS Management
resource "aws_iam_policy" "profile_board_iam_sts" {
  name        = "ProfileBoard-IAM-STS"
  path        = "/"
  description = "IAM policy for IAM role management and STS operations"

  policy = file("${path.module}/iam-roles-sts.json")

  lifecycle {
    ignore_changes = [policy]
  }

  tags = {
    Name        = "ProfileBoard-IAM-STS"
    Environment = "Infrastructure"
    Project     = "ProfileBoard"
  }
}

# Attach policies to the IAM user
resource "aws_iam_user_policy_attachment" "ec2_vpc_attachment" {
  user       = local.username
  policy_arn = aws_iam_policy.profile_board_ec2_vpc.arn
}

resource "aws_iam_user_policy_attachment" "api_elb_attachment" {
  user       = local.username
  policy_arn = aws_iam_policy.profile_board_api_elb.arn
}

resource "aws_iam_user_policy_attachment" "rds_ecr_attachment" {
  user       = local.username
  policy_arn = aws_iam_policy.profile_board_rds_ecr.arn
}

resource "aws_iam_user_policy_attachment" "iam_sts_attachment" {
  user       = local.username
  policy_arn = aws_iam_policy.profile_board_iam_sts.arn
}

# Outputs
output "policy_arns" {
  description = "ARNs of all created IAM policies"
  value = {
    ec2_vpc  = aws_iam_policy.profile_board_ec2_vpc.arn
    api_elb  = aws_iam_policy.profile_board_api_elb.arn
    rds_ecr  = aws_iam_policy.profile_board_rds_ecr.arn
    iam_sts  = aws_iam_policy.profile_board_iam_sts.arn
  }
}

output "attached_user" {
  description = "IAM username that policies are attached to"
  value       = local.username
}

output "user_arn" {
  description = "ARN of the IAM user"
  value       = var.iam_user_arn
}