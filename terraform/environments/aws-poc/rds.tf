######################################
# RDS Postgres + lakerunner/config databases
#
# RDS is publicly accessible for the POC so terraform can create the second
# database via the postgresql provider, and so operators can connect from
# their workstation for ad-hoc inspection. The security group restricts
# inbound 5432 to var.postgresql_allowed_cidr (default 0.0.0.0/0).
# Tighten that variable for any non-throwaway deployment.
######################################
resource "aws_db_subnet_group" "main" {
  count      = var.create_postgresql ? 1 : 0
  name       = "${local.name_prefix}-db-${random_id.suffix.hex}"
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_security_group" "rds" {
  count       = var.create_postgresql ? 1 : 0
  name_prefix = "${local.name_prefix}-rds-"
  description = "Lakerunner POC Postgres"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from inside the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Postgres from configured external CIDRs"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.postgresql_allowed_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  count                      = var.create_postgresql ? 1 : 0
  identifier                 = "${local.name_prefix}-pg-${random_id.suffix.hex}"
  engine                     = "postgres"
  engine_version             = var.postgresql_engine_version
  instance_class             = var.postgresql_instance_class
  allocated_storage          = var.postgresql_allocated_storage
  storage_type               = "gp3"
  db_name                    = var.postgresql_database_name
  username                   = var.postgresql_username
  password                   = local.postgresql_password
  db_subnet_group_name       = aws_db_subnet_group.main[0].name
  vpc_security_group_ids     = [aws_security_group.rds[0].id]
  publicly_accessible        = true
  skip_final_snapshot        = true
  deletion_protection        = false
  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  apply_immediately          = true
}

provider "postgresql" {
  host            = var.create_postgresql ? aws_db_instance.main[0].address : ""
  port            = var.create_postgresql ? aws_db_instance.main[0].port : 5432
  database        = var.postgresql_database_name
  username        = var.postgresql_username
  password        = local.postgresql_password
  sslmode         = "require"
  superuser       = false
  connect_timeout = 30
}

resource "postgresql_database" "configdb" {
  count = var.create_postgresql ? 1 : 0
  name  = var.postgresql_configdb_name
  owner = var.postgresql_username

  depends_on = [aws_db_instance.main]
}
