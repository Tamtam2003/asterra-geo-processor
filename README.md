# ASTERRA Geo Processing – DevOps Project

Owner: **Tamari Meydani**  
Region: **us-east-1**

This repository contains an end-to-end GIS data processing environment on AWS, including:

- VPC with public + private subnets
- RDS PostgreSQL with PostGIS
- S3 ingest bucket for GeoJSON files
- Flask-based processing service packaged in Docker
- Image registry in Amazon ECR
- CI/CD pipeline using GitHub Actions
- Infrastructure as Code using Terraform

---

## Architecture (High Level)

- **VPC (`astra-vpc`)**
  - **Public subnet** (`astra-public-a`) – EC2 instance running the Flask app in a Docker container.
  - **Private subnets** (`astra-private-a`, `astra-private-b`) – RDS PostgreSQL with PostGIS extension.
- **S3 bucket** (`tamari-asterra-ingest`) – stores GeoJSON files used as input.
- **EC2 instance** – pulls Docker image from ECR and exposes the app on port `5000`.
- **Amazon ECR** – stores the Docker image `asterra-geo-processor:latest`.
- **GitHub Actions** – on every push to `main`, builds and pushes the image to ECR.
- **Terraform** – creates and destroys all core infrastructure (VPC, subnets, RDS, S3, SGs).

You can draw this as a simple diagram:  
User → EC2 (Docker) → S3 + RDS (inside VPC), with ECR + GitHub Actions on the side.

---

## Tech Stack

- **Cloud:** AWS (VPC, EC2, RDS, S3, ECR, IAM)
- **Database:** PostgreSQL + PostGIS
- **App:** Python, Flask, GeoPandas, Shapely
- **Container:** Docker
- **CI/CD:** GitHub Actions
- **IaC:** Terraform (v1.5+), AWS provider v5+

---

## Repository Structure

```text
.
├── app/
│   ├── app.py          # Flask app – health + processing endpoints
│   └── __init__.py
├── Dockerfile          # GeoPandas-based image
├── requirements.txt    # Python dependencies
├── main.tf             # VPC, subnets, RDS, S3, SGs
├── variables.tf        # Input variables (region, cidr, db, bucket, etc.)
├── terraform.tfvars    # Local values (NOT committed with secrets in real life)
├── sqs-policy.json     # Example IAM/SQS policy (if needed)
└── .github/
    └── workflows/
        └── build-and-push.yml   # CI/CD: build & push image to ECR
Note: In a real production setup, terraform.tfvars with passwords and IPs would not be committed to the repo and secrets would live in a secure store.


Running the App Locally (Docker)

From the project root:

docker build -t geo-processor:dev .
docker run -d -p 5000:5000 \
  -e DB_HOST="YOUR-RDS-ENDPOINT" \
  -e DB_USER="gisuser" \
  -e DB_PASSWORD="YOUR_DB_PASSWORD" \
  -e DB_NAME="gisdb" \
  geo-processor:dev


Check health:
curl http://localhost:5000/health

Expected response:
{"status": "ok"}

Deployment on AWS (EC2 + ECR)
Build & push image locally (optional, CI/CD can handle this)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 526681946923.dkr.ecr.us-east-1.amazonaws.com

docker build -t geo-processor .
docker tag geo-processor:latest 526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest
docker push 526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest

Run container on EC2
On the EC2 instance (Amazon Linux / similar):

docker run -d -p 5000:5000 \
  526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest

Then test from outside:
http://<EC2-PUBLIC-IP>:5000/health

If Security Groups and routes are configured correctly, you should see:
{"status": "ok"}
Terraform – Infrastructure as Code

Core files:

main.tf
  VPC, subnets, route tables, internet gateway, security groups, RDS instance, S3 bucket.
variables.tf
Typed variables such as:
region
vpc_cidr
bucket_name
db_name, db_user, db_password
allowed_cidr (for RDS access)
ec2_key_name
terraform.tfvars

Actual values, for example:
region       = "us-east-1"
vpc_cidr     = "10.0.0.0/16"
bucket_name  = "tamari-asterra-ingest"
db_name      = "gisdb"
db_user      = "gisuser"
db_password  = "YOUR_STRONG_PASSWORD"
allowed_cidr = "YOUR.PUBLIC.IP.ADDR/32"
ec2_key_name = "tamari-ec2-key"

Typical workflow:
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

At the end of the project, a full cleanup of the environment was verified using:
terraform destroy

Security Notes
  Private RDS
   * The RDS PostgreSQL instance is deployed in private subnets and is not publicly exposed.
  Restricted DB Access
   * Access to RDS is restricted via a Security Group allowing TCP/5432 only from a specific allowed_cidr (<MY_IP>/32) instead of from the whole internet.
  Single public entrypoint
   * The EC2 instance (port 5000 HTTP) is the only public-facing component.
  Sensitive data
   * db_password is defined as sensitive in Terraform variables.
   * In a real production setup, it would be stored in AWS Secrets Manager / SSM Parameter Store rather than in terraform.tfvars.
  IAM & CI/CD
   * A dedicated IAM user and access keys are used by GitHub Actions with minimal permissions (primarily ECR access for image push).
  Infrastructure as Code
   * All infrastructure is described in Terraform, allowing easy review, versioning, and reproducible environments.

   CI/CD – GitHub Actions

The workflow file:
.github/workflows/build-and-push.yml:
Triggers on push to the main branch.
Uses repository secrets:
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
Configures AWS credentials.
Logs in to ECR.
Builds the Docker image.
Pushes the latest image to:
526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest
This creates a simple but complete CI/CD pipeline from:
Git → GitHub Actions → ECR → EC2 (Docker container)
