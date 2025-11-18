terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

########################
# VPC + Subnets + Routes
########################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "astra-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "astra-igw" }
}

# Public subnet (לשרתים ציבוריים בעתיד אם תרצי)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "astra-public-a" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "astra-public-rt" }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

# Private subnets ל-RDS (נדרש מינימום 2 AZs)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "astra-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "${var.region}b"
  tags              = { Name = "astra-private-b" }
}

########################
# Security Groups (RDS)
########################

resource "aws_security_group" "rds_sg" {
  name        = "astra-rds-sg"
  description = "Allow Postgres from your IP (temporary for setup)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from your IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr] # נגדיר בהפעלה
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "astra-rds-sg" }
}

########################
# S3 Bucket אמיתי
########################

resource "aws_s3_bucket" "ingest" {
  bucket = var.bucket_name
  tags   = { Name = var.bucket_name, Env = "dev" }
}


########################
# RDS PostgreSQL (Free Tier)
########################

resource "aws_db_subnet_group" "rds_subnets" {
  name       = "astra-rds-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "astra-rds-subnets" }
}

resource "aws_db_instance" "postgres" {
  identifier                 = "astra-postgres"
  engine                     = "postgres"
  engine_version             = "16"
  instance_class             = "db.t3.micro" # Free Tier
  allocated_storage          = 20
  storage_type               = "gp3"
  db_name                    = var.db_name
  username                   = var.db_user
  password                   = var.db_password
  db_subnet_group_name       = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids     = [aws_security_group.rds_sg.id]
  publicly_accessible        = true
  skip_final_snapshot        = true
  deletion_protection        = false
  multi_az                   = false
  auto_minor_version_upgrade = true
  tags                       = { Name = "astra-postgres" }
}

########################
# Outputs
########################

output "s3_bucket" {
  value = aws_s3_bucket.ingest.bucket
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}
