output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "redis_endpoint" {
  value = module.elasticache.endpoint
}

output "ecr_repositories" {
  value = module.ecr.repository_urls
}

output "sftp_public_ip" {
  value = module.sftp.public_ip
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}
