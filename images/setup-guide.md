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
# GitHub Actions automated CI/CD pipeline workflows

![CICD Pipeline diagram](images/CICD-pipeline.png)

##Step 1:  AWS OIDC Authentication Setup
This is Industry Best Practice for GitHub Actions to securely access AWS without storing long-lived credentials.

1. Create an IAM OIDC Identity Provider for GitHub Actions in your AWS account.

```aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1
  ```
## Verify
  ```aws iam list-open-id-connect-providers
  ```
2. Create an IAM Role with a trust policy that allows GitHub Actions to assume the role using OIDC.
```
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringLike": {
            "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
          }
        }
      }
    ]
  }' \
  --region us-east-1
```

## Replace:

    - YOUR_ACCOUNT_ID with your AWS account ID
    - YOUR_GITHUB_USERNAME/YOUR_REPO_NAME with your repository

3. Create the role:
```
aws iam create-role \
  --role-name GitHubActionsECSDeployRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json \
  --description "Role for GitHub Actions to deploy to ECS"
```
4. Attach Required Permissions
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:ListTaskDefinitions",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "arn:aws:iam::*:role/*ecs*",
      "Condition": {
        "StringLike": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
```
## Create and attach the policy:
```
# Create the policy
aws iam create-policy \
  --policy-name GitHubActionsECSDeployPolicy \
  --policy-document file://github-actions-permissions.json

# Attach it to the role
aws iam attach-role-policy \
  --role-name GitHubActionsECSDeployRole \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/GitHubActionsECSDeployPolicy
```
5. Configure GitHub Secrets
# Get the role ARN (you'll need this for GitHub secrets)
```aws iam get-role \
  --role-name GitHubActionsECSDeployRole \
  --query 'Role.Arn' \
  --output text
```

**Copy this ARN!** It should look like:
```
arn:aws:iam::180048382895:role/GitHubActionsECSRole
```
In your GitHub repository, go to Settings > Secrets and create the following secrets:
```
### Add GitHub Secrets

Go to your GitHub repository:
1. **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Add these secrets:

Name: AWS_ROLE_ARN
Value: arn:aws:iam::180048382895:role/GitHubActionsECSRole

Name: AWS_REGION
Value: us-east-1

Name: ECR_REPOSITORY
Value: attendance-app-dev

Name: ECS_CLUSTER
Value: attendance-app-dev-cluster

Name: ECS_SERVICE
Value: attendance-app-dev-service

Name: CONTAINER_NAME
Value: attendance-app-container

Name: DB_USERNAME
Value: dbadmin

Name: DB_PASSWORD
Value: your-db-Password
```
## Verify secrets:
gh secret list

# Create the GitHub Actions Workflow
In your GitHub repository, create a new file at `.github/workflows/deploy.yml` with the following content:

```


