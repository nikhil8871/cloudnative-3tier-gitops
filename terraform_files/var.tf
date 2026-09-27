variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}


variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "myvpc"
}

variable "vpc_cidr" {
  description = "Main CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-west-1c", "us-west-1a"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}



variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the EC2 Key Pair"
  type        = string
  default     = "mykeytest"
}

variable "public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTPy7DCn1MNdhnZBenRHkoIeMAwe/pBNkRtQAnVbACJ nikhi@Nikhil"

}

variable "backend_port" {
  type    = number
  default = 4000
}

variable "db_port" {
  type    = number
  default = 3306
}


variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "webappdb"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "database_subnets" {
  type    = list(string)
  default = ["10.0.5.0/24", "10.0.6.0/24"]
} 