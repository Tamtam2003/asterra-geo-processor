# ASTERRA Geo Processing – DevOps Project

Owner: **Tamari Meydani**  
Region: **us-east-1**

This repository contains an end-to-end GIS data processing environment on AWS, including:

- VPC with public + private subnets  
- RDS PostgreSQL with PostGIS  
- S3 ingest bucket for GeoJSON files  
- Flask-based processing service in Docker  
- Image registry on Amazon ECR  
- CI/CD with GitHub Actions  
- Infrastructure as Code using Terraform  

---

## 1. Architecture (High Level)

- **VPC (`astra-vpc`)**
  - **Public subnet (`astra-public-a`)** – EC2 instance running the Flask app in Docker.
  - **Private subnets (`astra-private-a`, `astra-private-b`)** – RDS PostgreSQL with PostGIS.

- **S3 Bucket (`tamari-asterra-ingest`)**
  - Stores GeoJSON files used as input.

- **EC2 Instance**
  - Pulls Docker image from ECR.
  - Exposes the app on port `5000`.

- **Amazon ECR**
  - Stores the image `asterra-geo-processor:latest`.

- **GitHub Actions**
  - Builds & pushes the Docker image on every push to `main`.

- **Terraform**
  - Creates/destroys VPC, subnets, RDS, S3, and security groups.

_Logical data flow:_  
User → EC2 (Docker, Flask) → S3 (GeoJSON) + RDS (PostGIS)  
GitHub Actions → ECR → EC2  
Terraform → AWS infrastructure

---

## 2. Tech Stack

- **Cloud:** AWS (VPC, EC2, RDS, S3, ECR, IAM)  
- **Database:** PostgreSQL + PostGIS  
- **Backend:** Python, Flask, GeoPandas, Shapely  
- **Container:** Docker  
- **CI/CD:** GitHub Actions  
- **IaC:** Terraform (v1.5+), AWS provider v5+  

---

## 3. Repository Structure

```text
.
├── app/
│   ├── app.py              # Flask endpoints (health + processing)
│   └── __init__.py
├── Dockerfile              # Docker image with GeoPandas
├── requirements.txt        # Python dependencies
├── main.tf                 # VPC, subnets, RDS, S3, SGs
├── variables.tf            # Input variables
├── terraform.tfvars        # Actual values (bucket, password, allowed_cidr, etc.)
├── sqs-policy.json         # Example IAM/SQS policy (optional)
└── .github/
    └── workflows/
        └── build-and-push.yml   # CI/CD to build & push to ECR
```

> **Note:** In production, secrets like `terraform.tfvars` would stay in a secret manager, not in the repo.

---

## 4. Running the App Locally (Docker)

From the project root:

```bash
docker build -t geo-processor:dev .
docker run -d -p 5000:5000 \
  -e DB_HOST="YOUR-RDS-ENDPOINT" \
  -e DB_USER="gisuser" \
  -e DB_PASSWORD="YOUR_DB_PASSWORD" \
  -e DB_NAME="gisdb" \
  geo-processor:dev
```

Check health:

```bash
curl http://localhost:5000/health
```

Expected:

```json
{"status": "ok"}
```

---

## 5. Deployment on AWS (EC2 + ECR)

### 5.1 Build & Push Image (optional if CI/CD is configured)

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 526681946923.dkr.ecr.us-east-1.amazonaws.com

docker build -t geo-processor .
docker tag geo-processor:latest 526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest
docker push 526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest
```

### 5.2 Run on EC2

```bash
docker run -d -p 5000:5000 \
  526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest
```

Test:

```
http://<EC2-PUBLIC-IP>:5000/health
```

---

## 6. Terraform – Infrastructure as Code

Core files:

- **main.tf** – VPC, Subnets, IGW, Route Tables, SGs, RDS, S3  
- **variables.tf** – typed variables  
- **terraform.tfvars** – real values (region, bucket, passwd, allowed_cidr, keypair)

Typical workflow:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Cleanup:

```bash
terraform destroy
```

---

## 7. Security Notes

- **RDS is private** inside private subnets (no public exposure).  
- DB access allowed only from specific CIDR:  
  `allowed_cidr = "<YOUR.IP>/32"`  
- EC2 is the only public entrypoint (port 5000).  
- `db_password` is marked sensitive (production: use Secrets Manager).  
- GitHub Actions uses IAM user with minimal ECR-only permissions.  
- All infra is IaC (Terraform) for repeatability & auditing.

---

## 8. CI/CD – GitHub Actions

Workflow (`.github/workflows/build-and-push.yml`) does:

- Trigger on push to **main**  
- Configure AWS credentials  
- Log in to ECR  
- Build Docker image  
- Push to:  
  `526681946923.dkr.ecr.us-east-1.amazonaws.com/asterra-geo-processor:latest`  

Pipeline flow:

> Git → GitHub Actions → ECR → EC2 (Docker container)
