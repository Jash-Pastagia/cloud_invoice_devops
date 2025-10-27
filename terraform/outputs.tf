# Terraform Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_cluster_certificate_authority" {
  description = "Certificate authority data for EKS cluster"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "eks_cluster_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

output "rds_endpoint_address" {
  description = "RDS instance endpoint address (without port)"
  value       = module.rds.db_endpoint_address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "Name of the database"
  value       = module.rds.db_name
}

output "rds_instance_id" {
  description = "ID of the RDS instance"
  value       = module.rds.db_instance_id
}

# MSK Outputs
output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = module.msk.cluster_arn
}

output "msk_bootstrap_brokers" {
  description = "MSK bootstrap brokers (plaintext)"
  value       = module.msk.bootstrap_brokers
  sensitive   = true
}

output "msk_bootstrap_brokers_tls" {
  description = "MSK bootstrap brokers (TLS)"
  value       = module.msk.bootstrap_brokers_tls
  sensitive   = true
}

output "msk_zookeeper_connect_string" {
  description = "MSK Zookeeper connection string"
  value       = module.msk.zookeeper_connect_string
  sensitive   = true
}

# Security Group Outputs
output "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster"
  value       = module.security_groups.eks_cluster_sg_id
}

output "rds_sg_id" {
  description = "Security group ID for RDS"
  value       = module.security_groups.rds_sg_id
}

output "msk_sg_id" {
  description = "Security group ID for MSK"
  value       = module.security_groups.msk_sg_id
}

# IAM Outputs
output "eks_node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = module.iam.eks_node_role_arn
}

output "app_service_account_role_arn" {
  description = "ARN of the application service account IAM role"
  value       = module.iam.app_service_account_role_arn
}

# Secrets Manager Outputs
output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing application credentials"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.app_secrets.name
}

# S3 Outputs
output "app_data_bucket_name" {
  description = "Name of the S3 bucket for application data"
  value       = aws_s3_bucket.app_data.id
}

output "app_data_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.app_data.arn
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

# Environment Configuration
output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

# Deployment Information
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    project      = var.project_name
    environment  = var.environment
    region       = var.aws_region
    eks_cluster  = module.eks.cluster_name
    rds_endpoint = module.rds.db_endpoint_address
    msk_brokers  = "Use 'terraform output msk_bootstrap_brokers_tls' to view"
    vpc_id       = module.vpc.vpc_id
  }
}

# Connection Strings (for kubectl and application configuration)
output "k8s_config_map_data" {
  description = "Data for Kubernetes ConfigMap"
  value = {
    DB_HOST  = module.rds.db_endpoint_address
    DB_PORT  = tostring(module.rds.db_port)
    DB_NAME  = var.db_name
    AWS_REGION = var.aws_region
  }
  sensitive = false
}

output "application_endpoints" {
  description = "Application endpoints after deployment"
  value = {
    database_endpoint = "${module.rds.db_endpoint_address}:${module.rds.db_port}"
    kafka_brokers     = "Retrieved from Secrets Manager: ${aws_secretsmanager_secret.app_secrets.name}"
    eks_api_endpoint  = module.eks.cluster_endpoint
  }
}
