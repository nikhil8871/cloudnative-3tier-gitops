########################1############################

resource "aws_security_group" "external_alb_sg" {
  name        = "external_alb_sg"
  description = "allow traffic coming from route53"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow traffic from route53 to LB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################2####################################

resource "aws_security_group" "worker_node_sg" {
  name        = "worker_node_sg"
  description = "allow traffic coming from internet gateway on port 80"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "allow HTTP traffic from external load balancer"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.external_alb_sg.id]
  }

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#########################3###################################

resource "aws_security_group" "db-sg" {
  name        = "db-sg"
  description = "allow traffic coming from backend on port ${var.db_port}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_node_sg.id]
  }

  ingress {
    description     = "allow ssh from backend to db "
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_node_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}