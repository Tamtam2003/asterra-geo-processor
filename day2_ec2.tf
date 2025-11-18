########################################
# Day 2 - EC2 Instances and Security Groups
########################################

# מוצא את Amazon Linux 2023 AMI הכי עדכני
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

########################################
# Security Groups
########################################

# Security Group לשרת הציבורי (HTTP + SSH מה-IP שלך)
resource "aws_security_group" "web_public_sg" {
  name        = "astra-web-public-sg"
  description = "Allow HTTP and SSH from the internet"
  vpc_id      = aws_vpc.main.id # אותו VPC שהקמת ביום 1

  # SSH מה-IP שלך בלבד
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["147.235.210.117/32"] # ה-IP העדכני שלך
  }

  # HTTP לכולם (פורט 80)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # יציאה לכל מקום (כדי לצאת לאינטרנט)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "astra-web-public-sg"
  }
}

# Security Group לשרת הפנימי – מקבל תעבורה מהשרת הציבורי
resource "aws_security_group" "app_private_sg" {
  name        = "astra-app-private-sg"
  description = "Internal app, reachable from public web instance"
  vpc_id      = aws_vpc.main.id

  # אפליקציה (Flask) על פורט 5000 מה־public
  ingress {
    description     = "App HTTP from public web instance"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_public_sg.id]
  }

  # SSH מהשרת הציבורי לשרת הפנימי
  ingress {
    description     = "SSH from public web instance"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_public_sg.id]
  }

  # יציאה לכל מקום (כדי לדבר עם RDS וכו')
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "astra-app-private-sg"
  }
}

########################################
# EC2 Instances
########################################

# EC2 ציבורי – עם Public IP
resource "aws_instance" "web_public" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web_public_sg.id]
  associate_public_ip_address = true
  key_name                    = var.ec2_key_name # key pair קיים ל-SSH

  tags = {
    Name = "astra-web-public"
  }
}

# EC2 פנימי – בלי Public IP, רק בתוך ה-VPC
resource "aws_instance" "app_private" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.app_private_sg.id]
  associate_public_ip_address = false
  key_name                    = var.ec2_key_name

  tags = {
    Name = "astra-app-private"
  }
}
