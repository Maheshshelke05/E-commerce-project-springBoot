variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "public_key_path" {
  description = "Path to public SSH key (.pub) relative to module directory"
  type        = string
  default     = "jenkins.pub"
}

variable "key_name" {
  description = "Base name for the AWS key pair (a random suffix will be appended)"
  default     = "jenkins-pair"
}

variable "sg_name" {
  description = "Base security group name"
  default     = "ecom"
}

variable "my_ip_cidr_v4" {
  description = "IPv4 CIDR to allow SSH (e.g., 203.0.113.5/32). Use your IP/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_name" {
  type    = string
  default = "ecomdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  description = "DB password (consider using secrets manager in prod)"
  type        = string
  sensitive   = true
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "existing_db_subnet_ids" {
  description = "list of existing subnet IDs (private subnets) in the VPC to use for RDS. Can be empty."
  type        = list(string)
  default     = []
}

variable "new_subnet_cidr" {
  description = "CIDR for new subnet to create"
  default     = "172.31.48.0/20"
}

variable "availability_zone" {
  default = "ap-south-1a"
}

variable "db_engine" {
  default = "mysql"
}

variable "db_engine_version" {
  default = "8.0"
}

variable "db_instance_class" {
  default = "db.t3.micro"
}

variable "db_port" {
  default = 3306
}

variable "app_repo_url" {
  description = "Git repo URL for the e-commerce Spring Boot app (your fork)"
  type        = string
  default     = "https://github.com/<YOUR-GITHUB-USERNAME>/E-commerce-project-springBoot.git"
}
