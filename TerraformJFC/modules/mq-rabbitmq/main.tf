# Amazon MQ con RabbitMQ para el microservicio de órdenes
# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "identifier" {
  type        = string
  description = "Identificador único del broker"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs de las subnets (1 para SINGLE_INSTANCE, 2 para ACTIVE_STANDBY)"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups"
}

variable "engine_type" {
  type        = string
  description = "Tipo de motor (RabbitMQ)"
  default     = "RabbitMQ"
}

variable "engine_version" {
  type        = string
  description = "Versión del motor"
  default     = "3.13"
}

variable "host_instance_type" {
  type        = string
  description = "Tipo de instancia"
  default     = "mq.t3.micro"
}

variable "deployment_mode" {
  type        = string
  description = "Modo de deployment (SINGLE_INSTANCE o CLUSTER_MULTI_AZ)"
  default     = "SINGLE_INSTANCE"
  validation {
    condition     = contains(["SINGLE_INSTANCE", "CLUSTER_MULTI_AZ"], var.deployment_mode)
    error_message = "Debe ser 'SINGLE_INSTANCE' o 'CLUSTER_MULTI_AZ'"
  }
}

variable "admin_username" {
  type        = string
  description = "Usuario administrador"
}

variable "admin_password" {
  type        = string
  description = "Contraseña de administrador"
  sensitive   = true
}

variable "publicly_accessible" {
  type        = bool
  description = "Accesible públicamente"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Amazon MQ Broker (RabbitMQ)
resource "aws_mq_broker" "this" {
  broker_name = var.identifier

  engine_type                = var.engine_type
  engine_version             = var.engine_version
  host_instance_type         = var.host_instance_type
  deployment_mode            = var.deployment_mode
  subnet_ids                 = var.subnet_ids
  security_groups            = var.security_group_ids
  publicly_accessible        = var.publicly_accessible
  auto_minor_version_upgrade = true

  user {
    username = var.admin_username
    password = var.admin_password
  }

  logs {
    general = true
  }

  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-mq" })
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "this" {
  name = "${var.identifier}-mq-credentials"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  secret_string = jsonencode({
    host     = aws_mq_broker.this.instances[0].endpoints[0]
    port     = 5671
    username = var.admin_username
    password = var.admin_password
    amqp_url = "amqps://${var.admin_username}:${var.admin_password}@${replace(aws_mq_broker.this.instances[0].endpoints[0], "amqps://", "")}:5671"
  })
}

# Outputs
output "id" {
  description = "ID del broker"
  value       = aws_mq_broker.this.id
}

output "broker_id" {
  description = "Broker ID"
  value       = aws_mq_broker.this.id
}

output "arn" {
  description = "ARN del broker"
  value       = aws_mq_broker.this.arn
}

output "endpoint" {
  description = "Endpoint del broker (IP o hostname)"
  value       = aws_mq_broker.this.instances[0].ip_address
  sensitive   = true
}

output "amqp_endpoints" {
  description = "Endpoints AMQP"
  value       = aws_mq_broker.this.instances[0].endpoints
  sensitive   = true
}

output "console_url" {
  description = "URL de la consola de administración"
  value       = aws_mq_broker.this.instances[0].console_url
}

output "admin_username" {
  description = "Usuario administrador"
  value       = var.admin_username
}

output "admin_password" {
  description = "Contraseña de administrador"
  value       = var.admin_password
  sensitive   = true
}

output "secret_arn" {
  description = "ARN del secreto"
  value       = aws_secretsmanager_secret.this.arn
}
