########################1############################

resource "aws_security_group" "external_alb-sg" {
  name        = "external-alb-sg"
  description = "allow traffic coming from user on port 80"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow traffic from user"
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

resource "aws_security_group" "web-front-sg" {
  name        = "web-front-sg"
  description = "allow traffic coming from internet gateway on port 80"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow HTTP traffic from internet gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_security_group" "internal-alb" {
  name        = "internal-alb"
  description = "allow traffic coming from frontend on port 80"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "allow traffic from frontend alb"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web-front-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##########################4#######################################

resource "aws_security_group" "app-backend-sg" {
  name        = "app-backend-sg"
  description = "allow traffic coming from frontend on port 4000"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "allow traffic from frontend"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web-front-sg.id]
  }
  ingress {
    description     = "allow ssh from frontend to backend "
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web-front-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##############################5####################################

resource "aws_security_group" "db-sg" {
  name        = "db-sg"
  description = "allow traffic coming from backend on port ${var.db_port}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app-backend-sg.id]
  }

  ingress {
    description     = "allow ssh from backend to db "
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.app-backend-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}