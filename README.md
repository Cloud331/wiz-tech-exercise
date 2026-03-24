# Wiz Technical Exercise

## Architecture

A two-tier web application on AWS consisting of:

- Tasky = A Go-based todo app running on EKS (Kubernetes 1.29) in private subnets
- MongoDB 4.4 = Database running on EC2 in a public subnet
- ALB = Internet-facing Application Load Balancer exposing the app
- S3 = Database backup storage

## Project Structure
```
wiz-tech-exercise/
├── terraform/           # Infrastructure-as-Code (all AWS resources)
│   ├── main.tf          # Provider config, SSH key
│   ├── variables.tf     # Input variable definitions
│   ├── vpc.tf           # VPC, subnets, NAT gateway
│   ├── ec2.tf           # MongoDB VM, security group, IAM
│   ├── eks.tf           # EKS cluster, node groups
│   ├── s3.tf            # Backup bucket, CloudTrail bucket
│   ├── ecr.tf           # Container registry
│   ├── security.tf      # CloudTrail, GuardDuty, IMDSv2
│   ├── outputs.tf       # Output values
│   └── scripts/
│       └── mongo-setup.sh
├── app/                 # Tasky application source
│   ├── Dockerfile       # Multi-stage build with wizexercise.txt
│   ├── wizexercise.txt  # Exercise requirement
│   ├── main.go
│   └── ...
├── k8s/                 # Kubernetes manifests
│   ├── namespace.yaml
│   ├── rbac.yaml        # ServiceAccount + cluster-admin binding
│   ├── deployment.yaml  # Tasky pods with env vars
│   ├── service.yaml     # ClusterIP service
│   └── ingress.yaml     # ALB ingress
└── .github/workflows/   # CI/CD pipelines
    ├── terraform.yml    # IaC: validate, scan, plan, apply
    └── app-deploy.yml   # App: build, scan, push, deploy
```

## Security Controls Implemented

| Control | Type | AWS Service |
|---------|------|-------------|
| Audit logging | Audit | CloudTrail (multi-region) |
| SSRF protection | Preventative | IMDSv2 required |
| Threat detection | Detective | GuardDuty (S3 + EKS) |
| IaC scanning | Shift-left | tfsec in CI pipeline |
| Image scanning | Shift-left | Trivy in CI pipeline |

## Intentional Weaknesses

This environment contains deliberate misconfigurations for demonstration purposes.
