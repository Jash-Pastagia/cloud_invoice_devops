# Cloud Invoice DevOps - Main Terraform Configuration
# This file orchestrates the deployment of all infrastructure components

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state configuration - uncomment and configure for production
  # backend "s3" {
  #   bucket         = "cloud-invoice-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# Data source for EKS cluster authentication
data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Helm Provider Configuration
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Local variables
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Kubernetes labels
  k8s_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.project_name
    "environment"                  = var.environment
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_nat_gateway  = var.enable_nat_gateway
  single_nat_gateway  = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # Allow access from specific CIDR blocks
  allowed_cidr_blocks = var.allowed_cidr_blocks

  tags = local.common_tags
}

# EKS Cluster Module
module "eks" {
  source = "./modules/eks"

  project_name    = var.project_name
  environment     = var.environment
  cluster_version = var.eks_cluster_version

  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  cluster_security_group_ids = [module.security_groups.eks_cluster_sg_id]

  node_group_desired_size = var.eks_node_group_desired_size
  node_group_min_size     = var.eks_node_group_min_size
  node_group_max_size     = var.eks_node_group_max_size
  node_group_instance_types = var.eks_node_group_instance_types

  enable_irsa = true

  tags = local.common_tags
}

# RDS PostgreSQL Module
module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.rds_sg_id]

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password # Consider using AWS Secrets Manager in production

  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  engine_version         = var.rds_engine_version
  backup_retention_period = var.rds_backup_retention_period
  multi_az               = var.rds_multi_az
  skip_final_snapshot    = var.environment != "production"

  tags = local.common_tags
}

# MSK (Managed Kafka) Module
module "msk" {
  source = "./modules/msk"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.msk_sg_id]

  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = var.msk_number_of_broker_nodes
  broker_instance_type   = var.msk_broker_instance_type
  broker_storage_size    = var.msk_broker_storage_size

  encryption_in_transit_client_broker = "TLS"
  encryption_at_rest_enabled         = true

  tags = local.common_tags
}

# IAM Roles and Policies Module
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  eks_cluster_name    = module.eks.cluster_name
  eks_oidc_provider   = module.eks.oidc_provider_arn
  rds_db_arn          = module.rds.db_instance_arn
  msk_cluster_arn     = module.msk.cluster_arn

  tags = local.common_tags
}

# Secrets Manager for application secrets
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}-app-secrets"
  description = "Application secrets for Cloud Invoice services"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-secrets"
    }
  )
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    DB_HOST          = module.rds.db_endpoint_address
    DB_PORT          = module.rds.db_port
    DB_NAME          = var.db_name
    DB_USER          = var.db_username
    DB_PASSWORD      = var.db_password
    JWT_SECRET       = var.jwt_secret
    KAFKA_BROKERS    = module.msk.bootstrap_brokers
    KAFKA_BROKERS_TLS = module.msk.bootstrap_brokers_tls
  })
}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${local.name_prefix}/application"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-logs"
    }
  )
}

# S3 Bucket for application data and backups
resource "aws_s3_bucket" "app_data" {
  bucket = "${local.name_prefix}-app-data-${random_string.suffix.result}"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-data"
    }
  )
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
