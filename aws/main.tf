provider "aws" {
  region = var.region
}

resource "aws_ecr_repository" "profile_board" {
  name = "profile-board"

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_db_instance" "profile_board_db" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "17.6"
  instance_class       = "db.t3.micro"
  db_name              = "profileboarddb"
  username             = "readwrite_user"
  password             = var.db_password
  parameter_group_name = "default.postgres17"
  skip_final_snapshot  = true
}

resource "aws_security_group" "ec2_sg" {
  name        = "profile-board-ec2-sg"
  description = "Allow inbound traffic for API Gateway integration"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_subnet" "private" {
  vpc_id     = data.aws_vpc.default.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "profile-board-private-subnet"
  }
}

resource "aws_lb" "profile_board_nlb" {
  name               = "profile-board-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.private.id]
}

resource "aws_lb_target_group" "profile_board_tg" {
  name     = "profile-board-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id
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

resource "aws_api_gateway_integration" "heartbeat_integration" {
  rest_api_id             = aws_api_gateway_rest_api.profile_board_api.id
  resource_id             = aws_api_gateway_resource.heartbeat.id
  http_method             = aws_api_gateway_method.heartbeat_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.profile_board_vpc_link.id
  uri                     = "http://${aws_lb.profile_board_nlb.dns_name}:8080/heartbeat"
}

resource "aws_api_gateway_deployment" "profile_board_api_deployment" {
  depends_on = [aws_api_gateway_integration.heartbeat_integration]
  rest_api_id = aws_api_gateway_rest_api.profile_board_api.id
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id    = aws_api_gateway_rest_api.profile_board_api.id
  deployment_id  = aws_api_gateway_deployment.profile_board_api_deployment.id
  stage_name     = "prod"
}

output "api_gateway_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.profile_board_api.id}.execute-api.${var.region}.amazonaws.com/prod/heartbeat"
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

resource "aws_instance" "profile_board_ec2" {
  ami                    = "ami-00b2df6cb966e5b60" # Amazon Linux 2 AMI (ap-southeast-2)
  instance_type          = "t3.micro"
  key_name               = "profile-board-key"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false
  subnet_id                  = data.aws_subnets.private.ids[0]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker git
    service docker start
    usermod -a -G docker ec2-user
    aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin ${aws_ecr_repository.profile_board.repository_url}
    docker pull ${aws_ecr_repository.profile_board.repository_url}:latest
    docker run -d -p 8080:8080 ${aws_ecr_repository.profile_board.repository_url}:latest
  EOF

  tags = {
    Name = "profile-board-ec2"
  }
}
