# =============================================================================
# main.tf — Provider configuration and shared resources
# =============================================================================
# This is the entry point for Terraform. It tells Terraform:
#   1. Which cloud provider to use (AWS)
#   2. What version of the provider to download
#   3. Shared resources used by multiple other files

# -----------------------------------------------------------------------------
# Terraform settings
# -----------------------------------------------------------------------------
terraform {
  # Require Terraform version 1.5 or higher
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"   # Download the AWS provider from HashiCorp
      version = "~> 5.0"          # Use any 5.x version (allows patch updates)
    }
  }

  # NOTE: For the exercise, we're using local state (stored on your machine).
  # In production, you'd use remote state in S3 so your team can collaborate:
  #
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "wiz-exercise/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# -----------------------------------------------------------------------------
# AWS Provider
# -----------------------------------------------------------------------------
# Terraform reads your AWS credentials from ~/.aws/credentials
# (set up by `aws configure` in Step 1)
provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Random ID for unique naming
# -----------------------------------------------------------------------------
# S3 bucket names must be globally unique across ALL AWS accounts.
# This generates a random 4-byte hex string (e.g., "a1b2c3d4") that we
# append to bucket names to avoid naming conflicts.
resource "random_id" "suffix" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# SSH Key Pair
# -----------------------------------------------------------------------------
# This creates an SSH key pair in AWS so you can log into the MongoDB EC2 instance.
# It uses the public key from your local machine.
#
# If you don't have an SSH key yet, generate one first:
#   ssh-keygen -t rsa -b 4096 -f ~/.ssh/wiz-exercise-key
#
# On Windows, the path would be: C:\Users\YourName\.ssh\wiz-exercise-key
resource "aws_key_pair" "deployer" {
  key_name   = "wiz-exercise-key"
  public_key = file(var.ssh_public_key_path)
}
