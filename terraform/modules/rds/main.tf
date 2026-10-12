###############################################################################
# Amazon RDS for MySQL.
# - Private subnets only (no public access)
# - Password generated and stored in AWS Secrets Manager (never in state as
#   plaintext you manage by hand; see note in README on state security)
# - Security group restricts ingress to the EKS nodes + Jenkins SG
###############################################################################

resource "random_password" "db" {
  length  = 24
  special = false # Avoid characters that complicate connection strings.
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}-db-credentials"
  recovery_window_in_days = 0 # Allow immediate delete for easy cleanup.
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
    host     = aws_db_instance.this.address
    port     = 3306
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "db" {
  name   = "${var.name}-db-sg"
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name}-db-sg" })

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      description     = "MySQL from allowed SG"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier              = "${var.name}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  multi_az                = false # Single-AZ to save cost for a demo.
  skip_final_snapshot     = true  # Easy teardown; do NOT do this in prod.
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true
  tags                    = var.tags
}
