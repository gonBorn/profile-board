provider "aws" {
  region = var.region
}

# Create Custom VPC
resource "aws_vpc" "profile_board_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "profile-board-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "profile_board_igw" {
  vpc_id = aws_vpc.profile_board_vpc.id

  tags = {
    Name = "profile-board-igw"
  }
}

# Public Subnet for NAT Gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.profile_board_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "profile-board-public-subnet"
  }
}

# Private Subnet for EC2
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.profile_board_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "profile-board-private-subnet"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.profile_board_igw]

  tags = {
    Name = "profile-board-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "profile_board_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.profile_board_igw]

  tags = {
    Name = "profile-board-nat-gateway"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.profile_board_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.profile_board_igw.id
  }

  tags = {
    Name = "profile-board-public-rt"
  }
}

# Route Table for Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.profile_board_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.profile_board_nat.id
  }

  tags = {
    Name = "profile-board-private-rt"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# ECR Repository
resource "aws_ecr_repository" "profile_board" {
  name = "profile-board"

  lifecycle {
    ignore_changes = all
  }
}

# Database Subnet Group
resource "aws_db_subnet_group" "profile_board_db_subnet_group" {
  name       = "profile-board-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.public.id]

  tags = {
    Name = "profile-board-db-subnet-group"
  }
}

# Database Security Group
resource "aws_security_group" "db_sg" {
  name        = "profile-board-db-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.profile_board_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "profile-board-db-sg"
  }
}

# RDS Database
resource "aws_db_instance" "profile_board_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "17.6"
  instance_class         = "db.t3.micro"
  db_name                = "profileboarddb"
  username               = "readwrite_user"
  password               = var.db_password
  parameter_group_name   = "default.postgres17"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.profile_board_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = "profile-board-db"
  }
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "profile-board-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.profile_board_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "profile-board-ec2-sg"
  }
}

# Security Group for Network Load Balancer
resource "aws_security_group" "nlb_sg" {
  name        = "profile-board-nlb-sg"
  description = "Security group for NLB"
  vpc_id      = aws_vpc.profile_board_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.profile_board_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "profile-board-nlb-sg"
  }
}

# Network Load Balancer
resource "aws_lb" "profile_board_nlb" {
  name               = "profile-board-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.private.id]

  tags = {
    Name = "profile-board-nlb"
  }
}

# Target Group for NLB
resource "aws_lb_target_group" "profile_board_tg" {
  name     = "profile-board-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = aws_vpc.profile_board_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
  }

  tags = {
    Name = "profile-board-tg"
  }
}

resource "aws_lb_target_group_attachment" "profile_board_ec2_attachment" {
  target_group_arn = aws_lb_target_group.profile_board_tg.arn
  target_id        = aws_instance.profile_board_ec2.id
  port             = 8080
}

resource "aws_lb_listener" "profile_board_listener" {
  load_balancer_arn = aws_lb.profile_board_nlb.arn
  port              = 8080
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.profile_board_tg.arn
  }
}

resource "aws_api_gateway_rest_api" "profile_board_api" {
  name        = "profile-board-api"
  description = "API Gateway for profile board heartbeat endpoint"
}

resource "aws_api_gateway_resource" "heartbeat" {
  rest_api_id = aws_api_gateway_rest_api.profile_board_api.id
  parent_id   = aws_api_gateway_rest_api.profile_board_api.root_resource_id
  path_part   = "heartbeat"
}

resource "aws_api_gateway_method" "heartbeat_get" {
  rest_api_id   = aws_api_gateway_rest_api.profile_board_api.id
  resource_id   = aws_api_gateway_resource.heartbeat.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_vpc_link" "profile_board_vpc_link" {
  name        = "profile-board-vpc-link"
  target_arns = [aws_lb.profile_board_nlb.arn]
}

# API Gateway Integration
resource "aws_api_gateway_integration" "heartbeat_integration" {
  rest_api_id             = aws_api_gateway_rest_api.profile_board_api.id
  resource_id             = aws_api_gateway_resource.heartbeat.id
  http_method             = aws_api_gateway_method.heartbeat_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.profile_board_vpc_link.id
  uri                     = "http://${aws_lb.profile_board_nlb.dns_name}:8080/heartbeat"

  request_parameters = {
    "integration.request.header.X-Forwarded-For" = "context.identity.sourceIp"
  }
}

# Method Response
resource "aws_api_gateway_method_response" "heartbeat_response_200" {
  rest_api_id = aws_api_gateway_rest_api.profile_board_api.id
  resource_id = aws_api_gateway_resource.heartbeat.id
  http_method = aws_api_gateway_method.heartbeat_get.http_method
  status_code = "200"

  response_headers = {
    "Access-Control-Allow-Origin" = true
  }
}

# Integration Response
resource "aws_api_gateway_integration_response" "heartbeat_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.profile_board_api.id
  resource_id = aws_api_gateway_resource.heartbeat.id
  http_method = aws_api_gateway_method.heartbeat_get.http_method
  status_code = aws_api_gateway_method_response.heartbeat_response_200.status_code

  response_headers = {
    "Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.heartbeat_integration]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "profile_board_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.heartbeat_integration,
    aws_api_gateway_integration_response.heartbeat_integration_response
  ]
  rest_api_id = aws_api_gateway_rest_api.profile_board_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.heartbeat.id,
      aws_api_gateway_method.heartbeat_get.id,
      aws_api_gateway_integration.heartbeat_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.profile_board_api.id
  deployment_id = aws_api_gateway_deployment.profile_board_api_deployment.id
  stage_name    = "prod"

  tags = {
    Name = "profile-board-api-prod-stage"
  }
}

# Outputs
output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL for heartbeat endpoint"
  value       = "https://${aws_api_gateway_rest_api.profile_board_api.id}.execute-api.${var.region}.amazonaws.com/prod/heartbeat"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.profile_board_vpc.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.profile_board_ec2.id
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.profile_board_nlb.dns_name
}

variable "db_password" {
  description = "The password for the RDS database."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "ap-southeast-2"
}

# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_ecr_role" {
  name = "profile-board-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "profile-board-ec2-ecr-role"
  }
}

# IAM Policy for ECR access
resource "aws_iam_role_policy" "ec2_ecr_policy" {
  name = "profile-board-ec2-ecr-policy"
  role = aws_iam_role.ec2_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "profile-board-ec2-profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# EC2 Instance
resource "aws_instance" "profile_board_ec2" {
  ami                         = "ami-00b2df6cb966e5b60" # Amazon Linux 2 AMI (ap-southeast-2)
  instance_type               = "t3.micro"
  key_name                    = "profile-board-key"
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false
  subnet_id                   = aws_subnet.private.id
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker git
    service docker start
    usermod -a -G docker ec2-user
    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.profile_board.repository_url}
    docker pull ${aws_ecr_repository.profile_board.repository_url}:latest
    docker run -d -p 8080:8080 --restart=always ${aws_ecr_repository.profile_board.repository_url}:latest
  EOF

  tags = {
    Name = "profile-board-ec2"
  }
}
