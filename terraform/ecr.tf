# ecr.tf - Elastic Container Registry
# ECR stores our Tasky container image. EKS pulls from here when deploying pods.

resource "aws_ecr_repository" "tasky" {
  name                 = "wiz-tasky"
  image_tag_mutability = "MUTABLE"    # Allows overwriting the "latest" tag
  force_delete         = true         # Allow Terraform to delete even if images exist

  # Scan images for CVEs when pushed — a security control you can demo
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = "wiz-exercise"
  }
}
