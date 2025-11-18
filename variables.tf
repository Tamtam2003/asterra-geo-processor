variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "bucket_name" {
  type        = string
  description = "חייב להיות יוניקלי בכל AWS"
}

variable "db_name" {
  type    = string
  default = "gis"
}

variable "db_user" {
  type    = string
  default = "gisuser"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "בחרי סיסמה חזקה"
}

variable "allowed_cidr" {
  type        = string
  description = "ה-IP שלך עם /32 לצורך חיבור זמני ל-RDS"
}

variable "ec2_key_name" {
  description = "Existing EC2 key pair name for SSH access"
  type        = string
}
