# Configuración General
variable "environment_name" {
  type        = string
  description = "Nombre del entorno (desarrollo, staging, produccion)"
  default     = "e-commerce-jfc-prod"
}

variable "aws_region" {
  type        = string
  description = "Región de AWS donde se desplegará la infraestructura"
  default     = "us-east-1"
}

# Configuración de VPC
variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Lista de Zonas de Disponibilidad"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnets" {
  type        = list(string)
  description = "CIDRs de las subnets privadas (donde corren los servicios)"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDRs de las subnets públicas (donde está el ALB)"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Configuración de ECS y Contenedores
variable "container_image_overrides" {
  type = object({
    ui       = optional(string)
    catalog  = optional(string)
    cart     = optional(string)
    checkout = optional(string)
    orders   = optional(string)
  })
  default     = {}
  description = "Overrides para las imágenes de contenedores (URIs de ECR o Docker Hub)"
}

variable "container_insights_setting" {
  type        = string
  description = "Configuración de Container Insights para ECS"
  default     = "enhanced"
  validation {
    condition     = contains(["enhanced", "disabled"], var.container_insights_setting)
    error_message = "Debe ser 'enhanced' o 'disabled'"
  }
}

variable "log_retention_days" {
  type        = number
  description = "Días de retención de logs en CloudWatch"
  default     = 30
}

# Configuración de Base de Datos - CATALOG (MySQL)
variable "catalog_db_name" {
  type        = string
  description = "Nombre de la base de datos del catálogo"
  default     = "catalog"
}

variable "catalog_db_username" {
  type        = string
  description = "Usuario maestro de la base de datos del catálogo"
  default     = "admin"
}

variable "catalog_db_password" {
  type        = string
  description = "Contraseña maestra de la base de datos del catálogo"
  sensitive   = true
}

# Configuración de Base de Datos - ORDERS (PostgreSQL)
variable "orders_db_name" {
  type        = string
  description = "Nombre de la base de datos de órdenes"
  default     = "orders"
}

variable "orders_db_username" {
  type        = string
  description = "Usuario maestro de la base de datos de órdenes"
  default     = "admin"
}

variable "orders_db_password" {
  type        = string
  description = "Contraseña maestra de la base de datos de órdenes"
  sensitive   = true
}

# Configuración de MQ (RabbitMQ)
variable "mq_admin_username" {
  type        = string
  description = "Usuario administrador de RabbitMQ"
  default     = "admin"
}

variable "mq_admin_password" {
  type        = string
  description = "Contraseña de administrador de RabbitMQ"
  sensitive   = true
}

# Configuración de Protección
variable "deletion_protection" {
  type        = bool
  description = "Habilitar protección contra eliminación en recursos críticos"
  default     = false
}

# Tags Adicionales
variable "tags" {
  type        = map(string)
  description = "Tags adicionales para recursos"
  default     = {}
}
