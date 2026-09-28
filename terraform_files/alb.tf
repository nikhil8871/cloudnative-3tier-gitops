# ==============================================================================
# AWS Application Load Balancer (External ALB)
# Listens on Port 80 (HTTP) and forwards to K8s Worker Node on NodePort 30080
# ==============================================================================

# --- 1. Application Load Balancer ---
resource "aws_lb" "external_alb" {
  name               = "${var.environment}-external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.external_alb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Name        = "${var.environment}-external-alb"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- 2. Target Group on NodePort 30080 ---
resource "aws_lb_target_group" "frontend_tg" {
  name        = "${var.environment}-frontend-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "30080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }

  tags = {
    Name        = "${var.environment}-frontend-tg"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- 3. HTTP Listener on Port 80 ---
resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}