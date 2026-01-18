# MÓDULO TAGS - Etiquetas base para todos los recursos

variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

locals {
  common_tags = {
    Environment = var.environment_name
    Project     = "e-commerce-JFC"
    ManagedBy   = "Terraform"
  }
}

output "result" {
  description = "Tags comunes para recursos"
  value       = local.common_tags
}

output "environment_name" {
  description = "Nombre del entorno"
  value       = var.environment_name
}
