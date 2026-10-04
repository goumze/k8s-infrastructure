# EKS Infrastructure Setup Guide

This Terraform configuration creates a fully functional Amazon EKS (Elastic Kubernetes Service) cluster with proper networking, security, and cluster configuration.

## Prerequisites

- AWS Account with appropriate IAM permissions
- Terraform >= 1.5
- AWS CLI configured with credentials
- GitHub Actions secrets configured

## What Gets Created

### Network Infrastructure
- VPC (10.0.0.0/16)
- 3 Public Subnets across 3 Availability Zones (ap-south-1a, ap-south-1b, ap-south-1c)
- Internet Gateway
- Public Route Table
- Security Groups for cluster and nodes

### EKS Cluster
- Cluster Name: `k8s-agentic-ai-cluster`
- Kubernetes Version: 1.31 (configurable)
- Managed Node Group: `green`
  - Instance Type: t3.xlarge (configurable)
  - Desired Size: 2 nodes
  - Min Size: 1 node
  - Max Size: 3 nodes
  - Storage: 100GB gp3 EBS volumes

### Cluster Add-ons
- CoreDNS
- VPC CNI
- kube-proxy
- EKS Pod Identity Agent

## Configuration Variables

Edit `terraform.tfvars` to customize:

```hcl
aws_region              = "ap-south-1"
cluster_version         = "1.31"
node_instance_type      = "t3.xlarge"
node_group_desired_size = 2
node_group_min_size     = 1
node_group_max_size     = 3
node_volume_size        = 100
```

## Local Deployment

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Validate Configuration

```bash
terraform validate
```

### 3. Plan the Infrastructure

```bash
terraform plan -out=tfplan
```

### 4. Apply the Configuration

```bash
terraform apply tfplan
```

**Cluster creation typically takes 10-15 minutes.**

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region ap-south-1 --name k8s-agentic-ai-cluster
```

### 6. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

## GitHub Actions Deployment

### Setup Secrets

Add these secrets to your GitHub repository:

1. `AWS_ACCESS_KEY_ID` - AWS Access Key
2. `AWS_SECRET_ACCESS_KEY` - AWS Secret Key
3. `AWS_REGION` - AWS Region (ap-south-1)

### Deployment Workflow

The GitHub Actions workflow (`terraform.yml`) will:

1. ✅ Checkout code
2. ✅ Setup Terraform
3. ✅ Configure AWS credentials
4. ✅ Initialize Terraform
5. ✅ Validate configuration
6. ✅ Plan infrastructure
7. ✅ Apply configuration (on main branch push only)
8. ✅ Display cluster information
9. ✅ Generate kubectl configuration command

## Monitoring Cluster Creation

### Real-time Logs

```bash
# Watch node status
watch -n 5 kubectl get nodes

# Watch all pods
kubectl get pods -A -w

# View cluster info
kubectl cluster-info

# Check CloudWatch logs
aws logs tail /aws/eks/k8s-agentic-ai-cluster/cluster --follow
```

## Troubleshooting

### Cluster Creation Fails

1. **Check AWS Credentials**: Verify your AWS credentials are correct
2. **IAM Permissions**: Ensure IAM user has EKS, EC2, VPC, and IAM permissions
3. **Resource Limits**: Check AWS account service quotas

### Nodes Not Ready

```bash
# Check node status
kubectl describe nodes

# Check node logs in CloudWatch
aws logs tail /aws/ec2/your-node-instance-id
```

### DNS Issues

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system | grep coredns

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod: nslookup kubernetes.default
```

## Scaling the Cluster

### Update Desired Node Count

Edit `terraform.tfvars`:

```hcl
node_group_desired_size = 5  # Change desired size
```

Then apply:

```bash
terraform apply
```

### Horizontal Pod Autoscaling

Install metrics-server (if not included):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Cost Estimation

### Monthly Estimate (t3.xlarge, 2 nodes)

- EKS Control Plane: ~$73
- EC2 Instances (t3.xlarge, 2 nodes): ~$240
- EBS Volume (100GB, 2 volumes): ~$20
- Data Transfer: ~$50 (variable)

**Total: ~$383/month** (varies by region and usage)

## Security Best Practices Implemented

✅ IAM Roles with minimal permissions  
✅ Security groups with restricted ingress  
✅ VPC isolation with public subnets  
✅ Encrypted EBS volumes  
✅ EKS Pod Identity for container authentication  
✅ CloudWatch monitoring  

## Destroy Infrastructure

⚠️ **WARNING**: This will delete all resources and cannot be undone.

```bash
terraform destroy
```

Or via GitHub Actions: Update workflow to uncomment destroy steps.

## Files Structure

```
k8s-infrastructure/
├── main.tf              # VPC, Subnets, Security Groups, EKS Cluster
├── providers.tf         # Provider configurations
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── backend.tf           # Terraform state backend (S3)
├── terraform.tfvars     # Variable values (optional)
├── .github/workflows/
│   └── terraform.yml    # GitHub Actions workflow
└── README.md            # This file
```

## Outputs

After successful deployment, get outputs:

```bash
# Get all outputs
terraform output

# Get specific outputs
terraform output cluster_name
terraform output cluster_endpoint
terraform output configure_kubectl
```

## Support & Documentation

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [EKS Module Documentation](https://github.com/terraform-aws-modules/terraform-aws-eks)

## Author Notes

This configuration is production-ready with:
- Proper error handling
- Comprehensive logging
- Automatic retry mechanisms
- CloudWatch integration
- S3 state management with DynamoDB locking

Happy deploying! 🚀
