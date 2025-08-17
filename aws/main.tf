provider "aws" {
  region = "ap-southeast-2"
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

# Find AMI ID for Amazon Linux 2 in ap-southeast-2 region
#  aws ec2 describe-images \
#       --owners amazon \
#       --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
#       --region ap-southeast-2 \
#       --query "Images | sort_by(@,&CreationDate)[-1].ImageId" \
#       --output text
resource "aws_instance" "profile_board_ec2" {
  ami           = "ami-00b2df6cb966e5b60" # Amazon Linux 2 AMI (ap-southeast-2)
  instance_type = "t3.micro"
  key_name      = "profile-board-key"

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

variable "db_password" {
  description = "The password for the RDS database."
  type        = string
  sensitive   = true
}
