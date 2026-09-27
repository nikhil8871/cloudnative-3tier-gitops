# 1. DB Subnet Group (attaches RDS to your database subnets)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# 2. RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier        = "${var.environment}-mysql-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db-sg.id]

  skip_final_snapshot = true  # Allows clean destroy without creating snapshot
  publicly_accessible = false # Completely private inside database subnets

  tags = {
    Name        = "${var.environment}-mysql-db"
    Environment = var.environment
  }
}
