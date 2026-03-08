# Automating AWS ECS Deployment —Infrastructure as Code with Terraform
This repository provides a complete Terraform configuration to automate the deployment of a containerized application on AWS ECS Fargate. The infrastructure includes VPC, subnets, security groups, load balancer, ECS cluster, task definitions, and optional Route 53 DNS setup.

## Pre-requisites

Before starting, ensure you have:

- AWS CLI installed and configured (aws configure)
- Terraform installed (version 1.0+)
- Docker installed locally (to pull and push images)
- Basic understanding of AWS services
- An AWS account with appropriate permissions
- Optional: A domain name (for SSL setup)

# Terraform Backend Setup

s3 bucket and dynmodb must exist prior to provisioning the infrastructure

## Create S3 bucket for state (use a unique name)
```
aws s3 mb s3://your-terraform-state-bucket-unique-name --region us-east-1
```
## Enable versioning
```
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket-unique-name \
  --versioning-configuration Status=Enabled
```
## Enable encryption
```
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket-unique-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```
## Create DynamoDB table for state locking
```
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
  ```
