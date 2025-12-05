terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  filter {
    name   = "isDefault"
    values = ["true"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "random_pet" "suffix" {
  length = 2
}

# Key pair (unique name using suffix)
resource "aws_key_pair" "mainkey" {
  key_name   = "${var.key_name}-${random_pet.suffix.id}"
  public_key = file("${path.module}/${var.public_key_path}")
}

# EC2 Security Group
resource "aws_security_group" "ec2_sg" {
  name   = "${var.sg_name}-ec2-${random_pet.suffix.id}"
  vpc_id = data.aws_vpc.default.id

  # SSH (IPv4)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr_v4]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App port (8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.sg_name}-ec2"
  }
}

# RDS Security Group — single resource, keep existing name to avoid replacement
resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"        # keep existing name if present in AWS
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.sg_name}-rds"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# New subnet in the AZ (used for EC2 and to include in DB subnet group)
resource "aws_subnet" "new_az" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = var.new_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "ecom-new-subnet-${var.availability_zone}-${random_pet.suffix.id}"
  }
}

# DB Subnet Group (uses existing list + newly created subnet)
resource "aws_db_subnet_group" "db_subnets" {
  name       = "ecom-db-subnet-group-${random_pet.suffix.id}"
  subnet_ids = concat(var.existing_db_subnet_ids, [aws_subnet.new_az.id])

  tags = {
    Name = "ecom-db-subnet-group"
  }
}

# RDS instance
resource "aws_db_instance" "ecom_db" {
  identifier              = "ecom-db-${random_pet.suffix.id}"
  allocated_storage       = var.allocated_storage
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true

  tags = {
    Name = "ecom-rds"
  }
}

# EC2 instance to host Spring Boot app
resource "aws_instance" "ecom_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.new_az.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = aws_key_pair.mainkey.key_name

  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    rds_endpoint = aws_db_instance.ecom_db.address
    db_username  = var.db_username
    db_password  = var.db_password
    repo_url     = var.app_repo_url
    db_name      = var.db_name
  })

  tags = {
    Name = "ecom-ec2"
  }

  depends_on = [aws_db_instance.ecom_db]
}
