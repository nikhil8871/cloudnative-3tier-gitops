output "aws_ami_id" {
  value = data.aws_ami.amazon_linux_2023.id
}

output "key_pair_name" {
  value = aws_key_pair.aws_key.key_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "database_subnet_ids" {
  value = module.vpc.database_subnets
}

# --- Backend Instance ---

output "backend_name" {
  value = aws_instance.app-backend.tags["Name"]
}

output "backend_id" {
  value = aws_instance.app-backend.id
}

output "backend_private_ip" {
  value = aws_instance.app-backend.private_ip
}

# --- Web Frontend Instance ---

output "web_frontend_name" {
  value = aws_instance.web-front.tags["Name"]
}

output "web_frontend_id" {
  value = aws_instance.web-front.id
}

output "web_frontend_public_ip" {
  value = aws_instance.web-front.public_ip
}

# --- Database ---

output "db_instance_id" {
  value = aws_db_instance.mysql.id
}

output "db_instance_ip_address" {
  value = aws_db_instance.mysql.address
}

output "db_instance_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "db_instance_port" {
  value = aws_db_instance.mysql.port
}

resource "local_file" "cluster_info" {
  filename = "${path.module}/cluster_outputs.txt"
  content  = <<-EOT
    VPC ID:           ${module.vpc.vpc_id}
    RDS Endpoint:     ${aws_db_instance.mysql.endpoint}
    RDS Address:      ${aws_db_instance.mysql.address}
    Frontend IP:      ${aws_instance.web-front.public_ip}
    Backend IP:       ${aws_instance.app-backend.private_ip}
  EOT
}

resource "local_file" "k8s_db_configmap" {
  filename = "${path.module}/../k8s/database/configmap.yaml"
  content  = <<-EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  labels:
    tier: data
data:
  DB_HOST: "${aws_db_instance.mysql.address}"
  DB_USER: "${var.db_username}"
  DB_NAME: "${var.db_name}"
EOT
}

