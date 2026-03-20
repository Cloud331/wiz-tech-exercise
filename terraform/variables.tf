# =============================================================================
# variables.tf — Input variable definitions
# =============================================================================
# Variables are like function parameters — they let you customise the
# deployment without changing the code. Values come from terraform.tfvars.

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/wiz-exercise-key.pub"
  # On Windows this resolves to C:\Users\YourName\.ssh\wiz-exercise-key.pub
}

variable "mongo_admin_user" {
  description = "MongoDB admin username"
  type        = string
  default     = "wizadmin"
}

variable "mongo_admin_pass" {
  description = "MongoDB admin password"
  type        = string
  sensitive   = true
  # sensitive = true means Terraform will show "(sensitive value)" in output
  # instead of the actual password. This prevents accidental exposure in logs.
}
