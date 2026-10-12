output "region" {
  value = var.region
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN holding DB credentials"
  value       = module.rds.secret_arn
}

output "jenkins_public_ip" {
  value = module.ec2_jenkins.public_ip
}

output "jenkins_url" {
  value = "http://${module.ec2_jenkins.public_ip}:8080"
}

output "configure_kubectl" {
  description = "Run this to get cluster access"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
