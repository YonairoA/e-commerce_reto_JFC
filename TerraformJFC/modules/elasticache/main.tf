# MÓDULO ELASTICACHE - Cache con Valkey/Redis
# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
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

variable "node_type" {
  type        = string
  description = "Tipo de nodo"
  default     = "cache.t3.micro"
}

variable "num_nodes" {
  type        = number
  description = "Número de nodos"
  default     = 1
}

variable "engine" {
  type        = string
  description = "Motor (valkey o redis)"
  default     = "valkey"
}

variable "engine_version" {
  type        = string
  description = "Versión del motor"
  default     = "7.2"
}

variable "port" {
  type        = number
  description = "Puerto"
  default     = 6379
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.environment_name}-${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.environment_name}-${var.identifier}-pg"
  family = var.engine == "valkey" ? "valkey7" : "redis7"

  description = "Parameter group para ${var.environment_name} ${var.identifier}"

  tags = var.tags
}

# ElastiCache Replication Group
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.identifier
  description          = "ElastiCache ${var.engine} para ${var.environment_name}"

  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_nodes
  parameter_group_name = aws_elasticache_parameter_group.this.name
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = var.security_group_ids
  port                 = var.port

  automatic_failover_enabled = var.num_nodes > 1 ? true : false
  multi_az_enabled           = var.num_nodes > 1 ? true : false

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_retention_limit = 0
  apply_immediately        = true

  tags = merge(var.tags, { Name = "${var.environment_name}-cache" })
}

# Outputs
output "id" {
  description = "ID del cluster"
  value       = aws_elasticache_replication_group.this.id
}

output "cluster_address" {
  description = "Dirección del cluster (hostname)"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "configuration_endpoint" {
  description = "Endpoint de configuración"
  value       = try(aws_elasticache_replication_group.this.configuration_endpoint_address, null)
}

output "primary_endpoint" {
  description = "Endpoint primario"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
  sensitive   = true
}

output "port" {
  description = "Puerto"
  value       = var.port
}

output "cache_nodes" {
  description = "Información de los nodos de cache"
  value       = aws_elasticache_replication_group.this.member_clusters
}
