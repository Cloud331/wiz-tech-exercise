# outputs.tf - Values displayed after terraform apply

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "mongo_public_ip" {
  description = "MongoDB EC2 public IP (for SSH access)"
  value       = aws_instance.mongo.public_ip
}

output "mongo_private_ip" {
  description = "MongoDB EC2 private IP (for K8s connection string)"
  value       = aws_instance.mongo.private_ip
}

output "mongo_connection_string" {
  description = "MongoDB connection string for Kubernetes deployment"
  value       = "mongodb://${var.mongo_admin_user}:<PASSWORD>@${aws_instance.mongo.private_ip}:27017/go-mongodb?authSource=admin"
  sensitive   = false
}

output "ecr_repository_url" {
  description = "ECR repository URL (for docker push)"
  value       = aws_ecr_repository.tasky.repository_url
}

output "eks_cluster_name" {
  description = "EKS cluster name (for kubectl config)"
  value       = module.eks.cluster_name
}

output "s3_backup_bucket" {
  description = "S3 backup bucket name"
  value       = aws_s3_bucket.db_backups.id
}

output "s3_backup_bucket_url" {
  description = "S3 backup bucket public URL (for demo)"
  value       = "https://${aws_s3_bucket.db_backups.id}.s3.amazonaws.com/"
}

output "ssh_command" {
  description = "SSH command to connect to MongoDB EC2"
  value       = "ssh -i ~/.ssh/wiz-exercise-key ec2-user@${aws_instance.mongo.public_ip}"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl for EKS"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
 
 