# eks.tf - EKS Kubernetes Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "wiz-exercise-cluster"
  cluster_version = "1.32"

  # Place the cluster in the VPC we created
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets   # Nodes in private subnets

  # Allow kubectl access from your machine
  cluster_endpoint_public_access = true

  # EKS add-ons — managed by AWS
  cluster_addons = {
    coredns                = {}   # DNS resolution inside the cluster
    kube-proxy             = {}   # Network proxying for Services
    vpc-cni                = {}   # AWS VPC networking for pods
    eks-pod-identity-agent = {}   # Pod identity for IRSA
  }

  # Worker nodes
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]   # 2 vCPU, 4GB RAM each
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      # Allow the nodes to pull images from ECR
      iam_role_additional_policies = {
        ecr_read = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  # Allow your IAM user to manage the cluster
  enable_cluster_creator_admin_permissions = true

  tags = {
    Project     = "wiz-exercise"
    Environment = "demo"
  }
}
