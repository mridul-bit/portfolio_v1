# infra/terraform/database.tf
#-------------------- random password generation for db and django key-----------------------
resource "random_password" "db_master_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "django_secret" {
  length  = 50
  special = true
  upper   = true
  lower   = true
  numeric = true
}
# --- -------------------AWS Secrets Manager for sensitive parm ------------------------- ---
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "/${var.project_name}/v1/db_credentials_1"
  description = "New RDS Postgres Master credentials and Django Secret Key."
  

  tags = {
    Name = "${var.project_name}-db_credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    DB_USERNAME       = var.db_username,
    DB_PASSWORD       = random_password.db_master_password.result,
    DB_NAME           = var.db_name, 
    
    DJANGO_SECRET_KEY = random_string.django_secret.result
  })
}

# --------------SSM for non-sensitive-------------------------

resource "aws_ssm_parameter" "resume_s3_key" {
  name  = "/${var.project_name}/s3/resume-key"
  type  = "String"
  # This is the path/filename of your resume file within the bucket
  value = "Mridul_SE_CV.pdf" 
}

# --- ------------------------RDS Instance (PostgreSQL) ---------------------------
resource "aws_db_instance" "postgres_db" {
  # Free-Tier configuration (db.t3.micro or db.t2.micro)
  allocated_storage      = 20 
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14.20"
  instance_class         = "db.t3.micro" 
  db_name                   = var.db_name
  username                = var.db_username
  # CRITICAL UPDATE: Use random provider output
  password                = random_password.db_master_password.result
 
  parameter_group_name   = "default.postgres14"
  skip_final_snapshot    = true 
  multi_az               = false 
  publicly_accessible    = false 
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "${var.project_name}-rds-postgres"
  }
  
 
  depends_on = [
    aws_security_group.rds,
    aws_secretsmanager_secret_version.db_credentials_version
    ]
}