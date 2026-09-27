locals {
  backend_user_data = <<-EOF
    #!/bin/bash
    if command -v dnf &> /dev/null; then
      dnf update -y
      dnf install -y docker
    else
      yum update -y
      yum install -y docker
    fi
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user

    docker pull nikhil8871/3-tier-backend:v1
    docker run -d \
      --name backend-app \
      --restart always \
      -p 4000:4000 \
      -e DB_HOST="${aws_db_instance.mysql.address}" \
      -e DB_USER="${var.db_username}" \
      -e DB_PWD="${var.db_password}" \
      -e DB_NAME="${var.db_name}" \
      nikhil8871/3-tier-backend:v1
  EOF

  frontend_user_data = <<-EOF
    #!/bin/bash
    if command -v dnf &> /dev/null; then
      dnf update -y
      dnf install -y docker
    else
      yum update -y
      yum install -y docker
    fi
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user

    docker pull nikhil8871/3-tier-frontend:v1
    docker run -d \
      --name frontend-app \
      --restart always \
      -p 80:80 \
      --add-host backend-service:${aws_instance.app-backend.private_ip} \
      nikhil8871/3-tier-frontend:v1
  EOF
}

# --- App Backend Instance (in us-west-1c) ---
resource "aws_instance" "app-backend" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  key_name               = aws_key_pair.aws_key.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app-backend-sg.id]
  subnet_id              = module.vpc.private_subnets[0] # us-west-1c (10.0.3.0/24)
  depends_on             = [aws_db_instance.mysql]
  user_data              = local.backend_user_data

  tags = {
    Name = "app-backend"
  }
}

# --- Web Frontend Instance (in us-west-1c) ---
resource "aws_instance" "web-front" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  key_name                    = aws_key_pair.aws_key.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.web-front-sg.id]
  subnet_id                   = module.vpc.public_subnets[0] # us-west-1c (10.0.1.0/24)
  associate_public_ip_address = true
  depends_on                  = [aws_instance.app-backend]
  user_data                   = local.frontend_user_data

  tags = {
    Name = "web-frontend"
  }
}