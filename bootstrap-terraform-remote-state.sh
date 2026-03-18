#! /bin/bash

# Create S3 bucket (versioning + encryption)
aws s3api create-bucket \
  --bucket attendance-app-bkt \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket attendance-app-bkt \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket attendance-app-bkt \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name attendance-app-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

## Set Up GitHub Actions OIDC Authentication
# Create the OIDC identity provider (one-time per AWS account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create the IAM role using the trust policy in this repo
aws iam create-role \
  --role-name GitHubActionsECSRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json

# Attach permissions
aws iam put-role-policy \
  --role-name GitHubActionsECSRole \
  --policy-name GitHubActionsPermissions \
  --policy-document file://github-actions-permissions.json
