# OUTPUTS - Información de salida de la Infraestructura E-Commerce

# -----------------------------------------------------------------------------
# URL de la Aplicación
# -----------------------------------------------------------------------------
output "application_url" {
  description = "URL para acceder a la aplicación e-commerce"
  value       = module.alb.url
}

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = module.alb.dns_name
}

# ECR - Repositorios de Imágenes
output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR para hacer push de imágenes"
  value       = module.ecr.repository_urls
}

output "ecr_image_uris" {
  description = "URIs de las imágenes con tag :latest"
  value       = module.ecr.image_uris
}

output "ecr_login_command" {
  description = "Comando para hacer login a ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# Comandos para subir imágenes Docker
output "docker_push_commands" {
  description = "Comandos para etiquetar y subir las imágenes pragma a ECR"
  value       = <<-EOT
    # 1. Login a ECR
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    # 2. Etiquetar imágenes
    docker tag pragma-ui-jfc:latest ${module.ecr.repository_urls["ui"]}:latest
    docker tag pragma-catalog-jfc:latest ${module.ecr.repository_urls["catalog"]}:latest
    docker tag pragma-cart-jfc:latest ${module.ecr.repository_urls["cart"]}:latest
    docker tag pragma-checkout-jfc:latest ${module.ecr.repository_urls["checkout"]}:latest
    docker tag pragma-orders-jfc:latest ${module.ecr.repository_urls["orders"]}:latest

    # 3. Subir imágenes
    docker push ${module.ecr.repository_urls["ui"]}:latest
    docker push ${module.ecr.repository_urls["catalog"]}:latest
    docker push ${module.ecr.repository_urls["cart"]}:latest
    docker push ${module.ecr.repository_urls["checkout"]}:latest
    docker push ${module.ecr.repository_urls["orders"]}:latest
  EOT
}

# VPC
output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = module.vpc.public_subnet_ids
}

# ECS
output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS"
  value       = module.ecs.cluster_arn
}

output "ecs_service_urls" {
  description = "URLs internas de los servicios (Service Discovery)"
  value       = module.ecs.service_urls
}

output "service_discovery_namespace" {
  description = "Namespace de Service Discovery"
  value       = module.ecs.service_discovery_namespace
}

output "log_group_name" {
  description = "Nombre del CloudWatch Log Group para ECS"
  value       = module.ecs.log_group_name
}

# Bases de Datos Aurora Serverless v2
output "catalog_db_endpoint" {
  description = "Endpoint de Aurora MySQL (Catalog)"
  value       = module.aurora_catalog.endpoint
  sensitive   = true
}

output "catalog_db_port" {
  description = "Puerto de Aurora MySQL (Catalog)"
  value       = module.aurora_catalog.port
}

output "orders_db_endpoint" {
  description = "Endpoint de Aurora PostgreSQL (Orders)"
  value       = module.aurora_orders.endpoint
  sensitive   = true
}

output "orders_db_port" {
  description = "Puerto de Aurora PostgreSQL (Orders)"
  value       = module.aurora_orders.port
}

# DynamoDB
output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB para el carrito"
  value       = module.dynamodb_carts.table_name
}

# ElastiCache
output "elasticache_endpoint" {
  description = "Endpoint de ElastiCache Valkey (Checkout)"
  value       = module.elasticache_checkout.cluster_address
}

output "elasticache_port" {
  description = "Puerto de ElastiCache"
  value       = module.elasticache_checkout.port
}

# MQ RabbitMQ
output "mq_endpoint" {
  description = "Endpoint de Amazon MQ RabbitMQ"
  value       = module.mq_orders.endpoint
  sensitive   = true
}

output "mq_broker_id" {
  description = "ID del broker de MQ"
  value       = module.mq_orders.broker_id
}

# Security Groups
output "alb_security_group_id" {
  description = "Security Group del ALB"
  value       = module.security_groups.alb
}

output "ecs_security_group_id" {
  description = "Security Group de los servicios ECS"
  value       = module.security_groups.ecs
}

# Información de Conexión para Debugging
output "ecs_exec_command" {
  description = "Comando para conectarse al contenedor via ECS Exec"
  value       = "aws ecs execute-command --cluster ${module.ecs.cluster_name} --task <TASK_ID> --container <SERVICE>-container --interactive --command /bin/sh"
}

# Resumen de Arquitectura
output "architecture_summary" {
  description = "Resumen de la arquitectura desplegada"
  value = {
    vpc = {
      cidr               = var.vpc_cidr
      nat_gateway        = "Habilitado (1 NAT Gateway)"
      availability_zones = var.availability_zones
    }
    compute = {
      platform = "ECS Fargate"
      services = ["ui", "catalog", "cart", "checkout", "orders"]
    }
    databases = {
      catalog = "Aurora Serverless v2 (MySQL)"
      orders  = "Aurora Serverless v2 (PostgreSQL)"
      cart    = "DynamoDB (On-Demand)"
    }
    cache = {
      checkout = "ElastiCache Valkey"
    }
    messaging = {
      orders = "Amazon MQ (RabbitMQ)"
    }
    load_balancer = {
      type = "Application Load Balancer"
      url  = module.alb.url
    }
  }
}
