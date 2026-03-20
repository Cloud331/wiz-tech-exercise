# =============================================================================
# vpc.tf — Network infrastructure
# =============================================================================
# This creates the entire network foundation:
#   - VPC (the isolated network)
#   - Public subnets (for ALB and MongoDB EC2)
#   - Private subnets (for EKS nodes)
#   - Internet Gateway (public internet access)
#   - NAT Gateway (outbound-only internet for private subnets)
#   - Route tables (traffic routing rules)

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "wiz-exercise-vpc"
  cidr = "10.0.0.0/16"   # 65,536 IP addresses

  # Two Availability Zones for redundancy
  azs = ["${var.aws_region}a", "${var.aws_region}b"]

  # Public subnets: ALB, MongoDB EC2, NAT Gateway live here
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # Private subnets: EKS nodes live here (no public IPs)
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

  # NAT Gateway: allows private subnet resources to reach the internet
  # (e.g., EKS nodes pulling container images from ECR)
  enable_nat_gateway   = true
  single_nat_gateway   = true    # One NAT GW (saves money; use one per AZ in production)

  # DNS: required for EKS — nodes need to resolve each other by hostname
  enable_dns_hostnames = true
  enable_dns_support   = true

  # These tags tell the AWS Load Balancer Controller which subnets to use
  # when creating the ALB for our Kubernetes Ingress
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/wiz-exercise-cluster" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/wiz-exercise-cluster" = "owned"
  }

  tags = {
    Project     = "wiz-exercise"
    Environment = "demo"
  }
}
