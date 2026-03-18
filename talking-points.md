# Interview Talking Points — AWS ECS Fargate Deployment with Terraform

Use these when presenting this project in a DevOps interview. Each point is tied to a specific, real decision in the codebase.

---

## Architecture & Design Decisions

**"Why ECS Fargate instead of EC2 or EKS?"**
> Fargate removes the need to manage EC2 instances, OS patching, and cluster capacity. For a web app with variable traffic, you pay per task-second rather than for idle capacity. EKS would be over-engineered for a single service — the added complexity of the control plane, node groups, and Kubernetes abstractions isn't justified here. If the workload grew to dozens of microservices, EKS would become the right call.

**"Why two private subnet tiers — app and DB — instead of one?"**
> Separation of concerns and defense in depth. The RDS security group only allows inbound PostgreSQL (port 5432) from the ECS tasks security group. Even if a misconfigured security group opened the app subnets wider, the DB subnets remain isolated. This mirrors a standard three-tier architecture: public (ALB), private app (ECS), private data (RDS).

**"Why a NAT Gateway? That's ~$35/month."**
> ECS Fargate tasks in private subnets need outbound internet access to pull images from ECR and send logs to CloudWatch. Without the NAT Gateway they can't reach those endpoints. The cost-optimised alternative is VPC endpoints for ECR and CloudWatch — which eliminates NAT costs for those specific services — but adds configuration complexity. For a dev environment, the NAT Gateway is the pragmatic choice. In production I'd add the VPC endpoints to reduce egress costs.

---

## Terraform & Infrastructure as Code

**"Your Terraform state is in S3 — what prevents two people from corrupting it simultaneously?"**
> The DynamoDB lock table in `backend.tf`. Any `terraform apply` that cannot acquire the lock fails immediately with a clear error message. I also set `encrypt = true` on the S3 backend so state at rest is AES-256 encrypted — important because `.tfstate` files can contain sensitive outputs like RDS endpoints and passwords.

**"Why is `terraform.tfvars` gitignored even though it has no real secrets in the repo?"**
> The `.gitignore` rule `*.tfvars` is intentional. Locally, `terraform.tfvars` holds real database credentials for development. If someone accidentally commits that file after filling in real values, those credentials are in git history permanently. Gitignoring the pattern globally prevents that class of mistake regardless of what the file contains at any given moment.

**"How do you manage variable values in CI/CD if tfvars is gitignored?"**
> All sensitive values are passed as `-var` flags sourced from GitHub Secrets (`DB_USERNAME`, `DB_PASSWORD`). Non-sensitive config like domain name uses GitHub Actions Variables, visible in the workflow as `${{ vars.DOMAIN_NAME }}`. This keeps credentials out of the codebase entirely while still being explicit about what configuration the pipeline needs.

---

## CI/CD Pipeline

**"Why OIDC for GitHub Actions instead of storing IAM access keys as secrets?"**
> OIDC tokens are short-lived — they expire when the workflow run ends. A leaked access key is valid indefinitely until rotated. OIDC eliminates the rotation problem entirely. The trust policy in `github-oidc-trust-policy.json` binds the IAM role to a specific GitHub repository via the `sub` claim, so even a stolen token from another repo can't assume this role. It's AWS's recommended approach and demonstrably more secure.

**"Walk me through what happens when a developer pushes a code change."**
> The `deploy.yml` workflow triggers on pushes to `main` that touch `files/`. It runs in three sequential jobs: first `test` (Flake8 linting), then `security-scan` (Trivy scans the built image for CVEs), then `build-and-deploy` only if both pass. The image is pushed to ECR tagged with the Git commit SHA and `latest`. The workflow then downloads the current ECS task definition, updates the image field to the new SHA tag, registers a new task definition revision, and triggers a rolling deployment. GitHub Actions waits for ECS to confirm the service is stable before the job completes successfully.

**"How does your rollback work?"**
> The `rollback.yml` workflow accepts an ECS task definition revision number as input. It forces the ECS service to that specific revision and waits for stability. In practice, each deployment prints the task definition revision in the job summary alongside the Git SHA, so there's a clear mapping. A more robust approach would be to redeploy the image by SHA directly rather than relying on revision numbers — which I'd implement as a follow-up.

**"Why does the deploy workflow tag images with both the commit SHA and `latest`?"**
> The SHA tag is immutable and traceable — you can always tell exactly which commit produced any image in ECR. The `latest` tag is a convenience pointer used by the ECS task definition as a fallback, and it's what the initial Terraform provisioning references before the first CI deploy runs. In a multi-environment setup I'd drop `latest` entirely and use only environment-specific tags like `dev-<sha>` and `prod-<sha>`.

---

## Security

**"The DB password is passed as a plain environment variable into the container — is that secure?"**
> It's not ideal. The connection string is visible in the ECS console under the task definition and potentially in CloudWatch logs if the app ever prints its environment. The production upgrade is AWS Secrets Manager: store the password there, reference it in the task definition using the `secrets:` field instead of `environment:`, and grant the ECS execution role `secretsmanager:GetSecretValue`. ECS fetches the secret at task launch — it never appears in the console or logs. The execution role IAM policy change is minimal and the application code doesn't need to change since the value is still injected as an env var.

**"What does the ECS task execution role actually need, and why is it separate from the task role?"**
> The **execution role** (`ecs-exec-role`) is used by the ECS control plane to pull the container image from ECR and write logs to CloudWatch. It holds `AmazonECSTaskExecutionRolePolicy`. The **task role** (`ecs-task-role`) is the identity the running application code assumes — it's what you'd attach policies to if the app needed to call S3, SQS, or other AWS services. Keeping them separate follows least-privilege: the app process never has permissions to pull ECR images, and the ECS agent never has application-level AWS access.

**"ECR has image scanning enabled — what does that actually do?"**
> On every push, ECR runs a scan using the Clair engine against the OS packages and installed libraries in the image, checking against the CVE database. Results appear in the ECR console with severity ratings (CRITICAL, HIGH, MEDIUM). The `deploy.yml` workflow also runs Trivy independently before the push, which catches vulnerabilities before they ever land in ECR. Two scanning layers: shift-left in CI and persistent scanning in the registry.

---

## Reliability & Observability

**"Why is the ECS health check grace period set to 300 seconds?"**
> On a cold start, the Flask app waits for the `db.t3.micro` RDS instance to accept connections, SQLAlchemy to run any pending migrations, and the process to bind to port 8000. If the grace period is too short, ECS marks newly launched tasks unhealthy before they finish starting, kills them, and starts replacements — creating a crash loop that looks like an application bug but is actually a timing issue. 300 seconds is conservative; I'd tune it down to ~90 seconds after measuring real P99 startup time in practice.

**"You have 2 desired ECS tasks across 2 AZs — what happens if one AZ goes down?"**
> The ALB health checks detect that the tasks in the failed AZ are unhealthy and stops routing traffic to them. ECS attempts to replace those tasks, but since the AZ is down it will launch replacements in the remaining healthy AZ. The service stays up with reduced capacity. For true resilience the desired count should be at least 3 so that after losing one AZ you still have more than one task running — preventing a single-task failure from causing downtime during the recovery period.

**"What monitoring do you have in place?"**
> Three layers: CloudWatch Container Insights on the ECS cluster for CPU, memory, and network metrics at the task level; CloudWatch Logs with a 7-day retention log group at `/ecs/attendance-app-dev` for application output; and a Prometheus `/metrics` endpoint on the Flask app itself exposing HTTP request counts, request duration histograms, and a custom `student_attendance_marked_total` counter. The Prometheus endpoint is ready to be scraped by any compatible collector — the natural next step would be adding an Amazon Managed Prometheus workspace and Grafana for dashboards.

---

## Challenges & What I'd Do Differently

| Challenge Faced | How It Was Addressed | What I'd Do in Production |
|---|---|---|
| `curl` missing in `python:3.11-slim` causing ECS health check failures | Added `apt-get install curl` to Dockerfile | Switch health check to a Python `urllib` script to avoid the extra OS package |
| DB credentials exposed as plain env vars in ECS task definition | Passed via GitHub Secrets at deploy time | Migrate to AWS Secrets Manager with task definition `secrets:` reference |
| NAT Gateway cost for dev workload | Accepted as necessary for simplicity | Add VPC endpoints for ECR (`api`, `dkr`) and CloudWatch to eliminate NAT dependency |
| Hardcoded domain name in CI workflow (from tutorial code) | Replaced with GitHub Actions Variables | Use a dedicated `dev` / `prod` environment in GitHub Actions with environment-specific variables |
| Terraform state bucket must be created manually before first apply | Documented in README bootstrap steps | Add a `bootstrap/` Terraform root module to provision the S3 and DynamoDB resources separately |
