terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "testerquintencosemans"
    key    = "user-management-api/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

# Default VPC ophalen
data "aws_vpc" "default" {
  default = true
}

# Subnets ophalen in die VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Probeer de bestaande security group te vinden
data "aws_security_group" "existing_app" {
  filter {
    name   = "group-name"
    values = ["user-management-api-sg"]
  }

  vpc_id = data.aws_vpc.default.id
}

# Maak een nieuwe security group als er geen bestaat
resource "aws_security_group" "app" {
  count       = data.aws_security_group.existing_app.id != "" ? 0 : 1
  name        = "user-management-api-sg"
  description = "Security group for User Management API"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP traffic to application port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "user-management-api-sg"
  }
}

# Selecteer automatisch juiste SG ID (bestaand of nieuw)
locals {
  sg_id = try(data.aws_security_group.existing_app.id, aws_security_group.app[0].id)
}


# EC2 instantie met Docker en image deploy
resource "aws_instance" "app" {
  ami                         = "ami-052064a798f08f0d3"
  instance_type                = "t3.micro"
  subnet_id                    = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids       = [local.sg_id]
  associate_public_ip_address  = true
  key_name                     = "labkey"

  user_data = base64encode(<<-EOF
      #!/bin/bash
      set -eux

      apt-get update -y
      apt-get install -y docker.io

      systemctl enable docker
      systemctl start docker

      docker pull quintencosemanspxl/nodejs-demo-app:latest
      docker run -d --name myapp -p 80:5000 \
          -e NODE_ENV=production \
          quintencosemanspxl/nodejs-demo-app:latest
  EOF
  )


  tags = {
    Name = "user-management-api"
  }

  lifecycle {
    create_before_destroy = true
  }
}
