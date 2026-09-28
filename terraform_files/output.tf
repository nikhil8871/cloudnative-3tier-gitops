# ==============================================================================
# Essential Terraform Outputs
# ==============================================================================

# --- Application Entrypoint (Frontend) ---
output "alb_url" {
  description = "Direct HTTP URL to access the frontend application"
  value       = "http://${aws_lb.external_alb.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.external_alb.dns_name
}

# --- Database Connection & Subnets ---
output "db_endpoint" {
  description = "AWS RDS MySQL endpoint address"
  value       = aws_db_instance.mysql.endpoint
}

output "db_address" {
  description = "AWS RDS MySQL host address"
  value       = aws_db_instance.mysql.address
}

output "database_subnet_ids" {
  description = "Subnet IDs where RDS database is deployed"
  value       = module.vpc.database_subnets
}

# --- Security Groups (The 3 Core SGs) ---
output "external_alb_sg_id" {
  description = "Security Group ID for External Application Load Balancer"
  value       = aws_security_group.external_alb_sg.id
}

output "worker_node_sg_id" {
  description = "Security Group ID for Kubernetes Worker Nodes (Port 30080 & SSH)"
  value       = aws_security_group.worker_node_sg.id
}

output "db_sg_id" {
  description = "Security Group ID for RDS MySQL Database (Port 3306 from Worker Node)"
  value       = aws_security_group.db-sg.id
}

# --- Network Subnets ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public Subnet IDs (used by External ALB)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private Subnet IDs (used by Compute / K8s nodes)"
  value       = module.vpc.private_subnets
}

# --- GitOps Automation & Cluster Info ---
resource "local_file" "k8s_db_configmap" {
  filename = "${path.module}/../k8s/database/configmap.yaml"
  content  = <<-EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  labels:
    tier: data
  annotations:
    argocd.argoproj.io/sync-wave: "1"
data:
  DB_HOST: "${aws_db_instance.mysql.address}"
  DB_USER: "${var.db_username}"
  DB_NAME: "${var.db_name}"
EOT
}

resource "local_file" "cluster_info" {
  filename = "${path.module}/cluster_outputs.txt"
  content  = <<-EOT
    VPC ID:           ${module.vpc.vpc_id}
    RDS Endpoint:     ${aws_db_instance.mysql.endpoint}
    RDS Address:      ${aws_db_instance.mysql.address}
    Application URL:  http://${aws_lb.external_alb.dns_name}
    External ALB SG:  ${aws_security_group.external_alb_sg.id}
    Worker Node SG:   ${aws_security_group.worker_node_sg.id}
    Database SG:      ${aws_security_group.db-sg.id}
  EOT
}
