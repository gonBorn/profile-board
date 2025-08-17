provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_ecr_repository" "profile_board" {
  name = "profile-board"
}

resource "aws_db_instance" "profile_board_db" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "17.6"
  instance_class       = "db.t3.micro"
  name                 = "profileboarddb"
  username             = "local"
  password             = var.db_password
  parameter_group_name = "default.postgres17"
  skip_final_snapshot  = true
}

resource "aws_instance" "profile_board_ec2" {
  ami           = "ami-0e5f882be1900dd7c" # Amazon Linux 2 AMI (ap-southeast-1)
  instance_type = "t3.micro"
  key_name      = "profile-board-key"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker git
    service docker start
    usermod -a -G docker ec2-user
    aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.profile_board.repository_url}
    docker pull ${aws_ecr_repository.profile_board.repository_url}:latest
    docker run -d -p 8080:8080 ${aws_ecr_repository.profile_board.repository_url}:latest
  EOF

  tags = {
    Name = "profile-board-ec2"
  }
}

variable "db_password" {
  description = "The password for the RDS database."
  type        = string
  sensitive   = true
}
