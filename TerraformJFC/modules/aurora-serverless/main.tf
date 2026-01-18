# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "engine" {
  type        = string
  description = "Motor de base de datos (aurora-mysql o aurora-postgresql)"
  validation {
    condition     = contains(["aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "El motor debe ser 'aurora-mysql' o 'aurora-postgresql'"
  }
}

variable "identifier" {
  type        = string
  description = "Identificador único del cluster"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs de las subnets"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups"
}

variable "serverless_v2_scaling_configuration" {
  type = object({
    max_capacity = number
    min_capacity = number
  })
  description = "Configuración de escalado Serverless v2"
  default = {
    max_capacity = 16
    min_capacity = 0.5
  }
}

variable "database_name" {
  type        = string
  description = "Nombre de la base de datos"
}

variable "master_username" {
  type        = string
  description = "Usuario maestro"
}

variable "master_password" {
  type        = string
  description = "Contraseña maestra"
  sensitive   = true
}

variable "deletion_protection" {
  type        = bool
  description = "Habilitar protección contra eliminación"
  default     = false
}

variable "backup_retention_days" {
  type        = number
  description = "Días de retención de backups"
  default     = 7
}

variable "kms_key_id" {
  type        = string
  description = "ID de la clave KMS para cifrado"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Variables Locales
locals {
  parameter_group_family = var.engine == "aurora-mysql" ? "aurora-mysql8.0" : "aurora-postgresql15"
  engine_version         = var.engine == "aurora-mysql" ? "8.0.mysql_aurora.3.05.2" : "15.4"
  db_port                = var.engine == "aurora-mysql" ? 3306 : 5432
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.identifier}-subnet-group" })
}

# DB Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.identifier}-pg"
  family      = local.parameter_group_family
  description = "Parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.engine == "aurora-mysql" ? [1] : []
    content {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  }

  dynamic "parameter" {
    for_each = var.engine == "aurora-mysql" ? [1] : []
    content {
      name  = "character_set_client"
      value = "utf8mb4"
    }
  }

  tags = var.tags
}

# RDS Cluster Aurora Serverless v2
resource "aws_rds_cluster" "this" {
  cluster_identifier = var.identifier
  engine             = var.engine
  engine_mode        = "provisioned"
  engine_version     = local.engine_version

  # Configuración Serverless v2
  serverlessv2_scaling_configuration {
    max_capacity = var.serverless_v2_scaling_configuration.max_capacity
    min_capacity = var.serverless_v2_scaling_configuration.min_capacity
  }

  # Configuración de base de datos
  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  # Networking
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.this.name

  # Cifrado
  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  # Backup
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Snapshot final antes de eliminar
  skip_final_snapshot       = true
  final_snapshot_identifier = var.deletion_protection ? "${var.identifier}-final-snapshot" : null

  deletion_protection = var.deletion_protection
  port                = local.db_port

  # Parameter group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  # Logs
  enabled_cloudwatch_logs_exports = var.engine == "aurora-mysql" ? ["error", "slowquery"] : ["postgresql"]

  tags = merge(var.tags, { Name = "${var.identifier}-cluster" })
}

# RDS Cluster Instance (Serverless v2)
resource "aws_rds_cluster_instance" "writer" {
  count = 1

  identifier         = "${var.identifier}-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  publicly_accessible = false

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = merge(var.tags, { Name = "${var.identifier}-writer" })
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "this" {
  name = "${var.identifier}-db-credentials"

  tags = merge(var.tags, { Name = "${var.identifier}-secret" })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  secret_string = jsonencode({
    host     = aws_rds_cluster.this.endpoint
    port     = aws_rds_cluster.this.port
    username = var.master_username
    password = var.master_password
    database = var.database_name
    engine   = var.engine
  })
}

# Outputs
output "id" {
  description = "ID del cluster"
  value       = aws_rds_cluster.this.id
}

output "arn" {
  description = "ARN del cluster"
  value       = aws_rds_cluster.this.arn
}

output "endpoint" {
  description = "Endpoint del cluster (writer)"
  value       = aws_rds_cluster.this.endpoint
  sensitive   = true
}

output "reader_endpoint" {
  description = "Endpoint de lectura (reader)"
  value       = aws_rds_cluster.this.reader_endpoint
  sensitive   = true
}

output "port" {
  description = "Puerto del cluster"
  value       = aws_rds_cluster.this.port
}

output "master_username" {
  description = "Usuario maestro"
  value       = var.master_username
  sensitive   = true
}

output "master_password" {
  description = "Contraseña maestra"
  value       = var.master_password
  sensitive   = true
}

output "database_name" {
  description = "Nombre de la base de datos"
  value       = var.database_name
}

output "secret_arn" {
  description = "ARN del secreto en Secrets Manager"
  value       = aws_secretsmanager_secret.this.arn
}

output "engine" {
  description = "Motor de base de datos"
  value       = var.engine
}
