terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Provider Doc - https://registry.terraform.io/providers/hashicorp/aws/latest
provider "aws" {
  # Configuration options
  region = "us-east-1"

  default_tags {
    tags = var.resource_tags
  }

  # Set Environment Variables in your terminal for Auth
    # export AWS_ACCESS_KEY_ID="anaccesskey"
    # export AWS_SECRET_ACCESS_KEY="asecretkey"
    # export AWS_SESSION_TOKEN="aSessionToken"
}

## Input Variables
variable "db_password" {
   sensitive = true
   default = null
   }
variable "resource_tags" {}
variable "additional_db_names" {
  default = ["chinook", "lego", "netflix", "periodic_table", "titanic", "pagila"]
  description = "List of additional database names to create."
}

# Generate a random password and assign it to db_password variable
resource "random_password" "db_password" {
  length           = 12
  special          = true
  override_special = "!@#$%"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Generate a random unique ID for the RDS identifier
resource "random_id" "unique_suffix" {
  byte_length = 4
}
# Assign generated password to db_password variable
#output "db_password" {
#  value       = random_password.db_password.result
#  sensitive   = true
#}



############
## RDS Setup
############
# Available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Database VPC - https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "lab-rds-vpc-${random_id.unique_suffix.hex}"
  cidr            = "10.0.0.0/16"
  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Create Security Groups
resource "aws_security_group" "rds" {
  name   = "lab-rds-sg-${random_id.unique_suffix.hex}"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Subnet Group
resource "aws_db_subnet_group" "database_sng" {
  name       = "lab_rds_sng-${random_id.unique_suffix.hex}"
  subnet_ids = module.vpc.public_subnets
}

# Log Connections
resource "aws_db_parameter_group" "labrds" {
  name   = "lab-rds-${random_id.unique_suffix.hex}"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

# # Create PostGreSQL DB
resource "aws_db_instance" "labrds" {
  identifier             = "cyera-se-lab-${random_id.unique_suffix.hex}"
  allocated_storage      = 10
  db_name                = "selabdb"
  db_subnet_group_name   = aws_db_subnet_group.database_sng.name
  engine                 = "postgres"
  # engine_version         = "14.7"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = random_password.db_password.result
  parameter_group_name   = aws_db_parameter_group.labrds.name
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
}

resource "null_resource" "db_init" {
  provisioner "local-exec" {
    command = <<EOT
 # Create additional databases
      %{ for db_name in var.additional_db_names ~}
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result}" -c "CREATE DATABASE ${db_name};"
      %{ endfor ~}
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=labrds" -f labrds-roles.sql /dev/null 2>&1
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=labrds" -f labrds-database.sql /dev/null 2>&1
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=pagila" -f pagila.sqli /dev/null 2>&1
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=netflix" -f netflix.sql /dev/null 2>&1
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=chinook" -f chinook.sql /dev/null 2>&1
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=titanic" -f titanic.sql /dev/null 2>&1
      psql "host=${aws_db_instance.labrds.address} port=${aws_db_instance.labrds.port} user=postgres password=${random_password.db_password.result} dbname=lego" -f lego.sql /dev/null 2>&1
    EOT
  }

  depends_on = [aws_db_instance.labrds]
}


##
## Outputs
##
output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.labrds.address
  sensitive   = false
}

output "rds_dbname" {
  description = "RDS instance dbname"
  value       = aws_db_instance.labrds.db_name
  sensitive   = false
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.labrds.port
  sensitive   = false
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.labrds.username
  sensitive   = false
}

#output "rds_pwd" {
#  description = "RDS instance pwd"
#  value       =  var.db_password
#  sensitive   = true
#} 