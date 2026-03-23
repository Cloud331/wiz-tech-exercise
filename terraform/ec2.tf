# =============================================================================
# ec2.tf — MongoDB VM, Security Group, IAM Role
# =============================================================================

# -----------------------------------------------------------------------------
# Find the latest Amazon Linux 2 AMI (intentionally outdated OS — weakness #1)
# -----------------------------------------------------------------------------
# This data source queries AWS for the most recent Amazon Linux 2 AMI.
# Amazon Linux 2 reached end-of-life June 2025 — no more security patches.
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get current AWS account ID (needed for IAM ARNs)
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Security Group for MongoDB EC2
# -----------------------------------------------------------------------------
resource "aws_security_group" "mongo" {
  name_prefix = "mongo-sg-"
  description = "Security group for MongoDB EC2 instance"
  vpc_id      = module.vpc.vpc_id

  # INTENTIONAL WEAKNESS #2: SSH open to the entire internet
  # In production: restrict to your IP or use Systems Manager Session Manager
  ingress {
    description = "SSH from anywhere (intentional weakness)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB only accessible from K8s private subnets
  # This satisfies: "Access must be restricted to Kubernetes network access only"
  ingress {
    description = "MongoDB from K8s private subnets only"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    # This resolves to ["10.0.10.0/24", "10.0.11.0/24"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mongo-sg" }
}

# -----------------------------------------------------------------------------
# IAM Role for MongoDB EC2 (intentionally overpermissive — weakness #3)
# -----------------------------------------------------------------------------

# The role itself — defines WHO can use it (EC2 instances)
resource "aws_iam_role" "mongo_ec2" {
  name = "wiz-mongo-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Project = "wiz-exercise" }
}

# INTENTIONAL WEAKNESS #3: Overpermissive policies
# The VM only needs s3:PutObject on one bucket, but we give it full EC2 + S3 access
resource "aws_iam_role_policy_attachment" "mongo_ec2_full" {
  role       = aws_iam_role.mongo_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "mongo_s3_full" {
  role       = aws_iam_role.mongo_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Instance Profile wraps the role so it can be attached to EC2
resource "aws_iam_instance_profile" "mongo" {
  name = "wiz-mongo-ec2-profile"
  role = aws_iam_role.mongo_ec2.name
}

# -----------------------------------------------------------------------------
# EC2 Instance — MongoDB Server
# -----------------------------------------------------------------------------
resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"        # 2 vCPU, 4GB RAM
  subnet_id                   = module.vpc.public_subnets[0]  # Public subnet (for SSH)
  vpc_security_group_ids      = [aws_security_group.mongo.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo.name
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true   # Needed for SSH access from internet

  # Root volume — 20GB is enough for MongoDB data + backups
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # The user_data script runs on first boot — installs MongoDB, configures auth,
  # creates the backup cron job. templatefile() replaces variables in the script.
  user_data = templatefile("${path.module}/scripts/mongo-setup.sh", {
    mongo_admin_user = var.mongo_admin_user
    mongo_admin_pass = var.mongo_admin_pass
    s3_bucket_name   = aws_s3_bucket.db_backups.id
  })

  tags = {
    Name    = "wiz-mongo-server"
    Project = "wiz-exercise"
  }

  # Don't replace the instance if user_data changes — just update in place
  lifecycle {
    ignore_changes = [user_data]
  }
}
