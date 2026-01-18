# MÓDULO ECS - Cluster y Servicios con AWS Fargate
# Orquestación de contenedores para microservicios e-commerce
# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs de las subnets privadas"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "IDs de las subnets públicas"
}

variable "cluster_name" {
  type        = string
  description = "Nombre del cluster ECS"
}

variable "container_insights_setting" {
  type        = string
  description = "Configuración de Container Insights"
  default     = "enhanced"
}

variable "log_retention_days" {
  type        = number
  description = "Días de retención de logs"
  default     = 30
}

# Secrets de Bases de Datos
variable "catalog_db_secrets" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
    database = string
  })
  description = "Secrets de la base de datos del catálogo"
}

variable "orders_db_secrets" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
    database = string
  })
  description = "Secrets de la base de datos de órdenes"
}

# DynamoDB
variable "dynamodb_table_name" {
  type        = string
  description = "Nombre de la tabla DynamoDB"
}

variable "dynamodb_policy_arn" {
  type        = string
  description = "ARN del policy de DynamoDB"
}

# Redis/Valkey
variable "redis_endpoint" {
  type        = string
  description = "Endpoint de Redis"
}

variable "redis_port" {
  type        = string
  description = "Puerto de Redis"
}

# MQ RabbitMQ
variable "mq_endpoint" {
  type        = string
  description = "Endpoint de MQ"
}

variable "mq_username" {
  type        = string
  description = "Usuario de MQ"
}

variable "mq_password" {
  type        = string
  description = "Contraseña de MQ"
  sensitive   = true
}

# ALB
variable "alb_target_group_arn" {
  type        = string
  description = "ARN del target group del ALB"
  default     = ""
}

variable "alb_security_group_id" {
  type        = string
  description = "ID del security group del ALB"
  default     = ""
}

# Security Group para servicios ECS (viene del módulo security-groups)
variable "ecs_security_group_id" {
  type        = string
  description = "ID del security group para los servicios ECS"
}

# Container Images
variable "container_image_overrides" {
  type = object({
    ui       = optional(string)
    catalog  = optional(string)
    cart     = optional(string)
    checkout = optional(string)
    orders   = optional(string)
  })
  default     = {}
  description = "Overrides para imágenes de contenedores"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Datos y Variables Locales
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  default_images = {
    ui       = "public.ecr.aws/aws-containers/retail-store-sample-ui:0.2.0"
    catalog  = "public.ecr.aws/aws-containers/retail-store-sample-catalog:0.2.0"
    cart     = "public.ecr.aws/aws-containers/retail-store-sample-cart:0.2.0"
    checkout = "public.ecr.aws/aws-containers/retail-store-sample-checkout:0.2.0"
    orders   = "public.ecr.aws/aws-containers/retail-store-sample-orders:0.2.0"
  }

  images = {
    ui       = coalesce(try(var.container_image_overrides.ui, null), local.default_images.ui)
    catalog  = coalesce(try(var.container_image_overrides.catalog, null), local.default_images.catalog)
    cart     = coalesce(try(var.container_image_overrides.cart, null), local.default_images.cart)
    checkout = coalesce(try(var.container_image_overrides.checkout, null), local.default_images.checkout)
    orders   = coalesce(try(var.container_image_overrides.orders, null), local.default_images.orders)
  }

  # Configuración de servicios
  services = {
    catalog = {
      name   = "catalog"
      port   = 8080
      cpu    = 512
      memory = 1024
      environment = {
        RETAIL_CATALOG_PERSISTENCE_PROVIDER = "mysql"
        RETAIL_CATALOG_PERSISTENCE_DB_NAME  = var.catalog_db_secrets.database
        RETAIL_CATALOG_PERSISTENCE_ENDPOINT = var.catalog_db_secrets.host
        RETAIL_CATALOG_PERSISTENCE_USER     = var.catalog_db_secrets.username
        RETAIL_CATALOG_PERSISTENCE_PASSWORD = var.catalog_db_secrets.password
      }
      health_path      = "/health"
      task_policy_arns = []
    }

    cart = {
      name   = "cart"
      port   = 8080
      cpu    = 512
      memory = 1024
      environment = {
        RETAIL_CART_PERSISTENCE_PROVIDER            = "dynamodb"
        RETAIL_CART_PERSISTENCE_DYNAMODB_TABLE_NAME = var.dynamodb_table_name
        AWS_REGION                                  = data.aws_region.current.name
      }
      health_path      = "/health"
      task_policy_arns = [var.dynamodb_policy_arn]
    }

    checkout = {
      name   = "checkout"
      port   = 8080
      cpu    = 512
      memory = 1024
      environment = {
        RETAIL_CHECKOUT_PERSISTENCE_PROVIDER  = "redis"
        RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL = "redis://${var.redis_endpoint}:${var.redis_port}"
        RETAIL_CHECKOUT_ENDPOINTS_ORDERS      = "http://orders.${local.service_discovery_namespace}:8080"
      }
      health_path      = "/health"
      task_policy_arns = []
    }

    orders = {
      name   = "orders"
      port   = 8080
      cpu    = 512
      memory = 1024
      environment = {
        RETAIL_ORDERS_MESSAGING_PROVIDER           = "rabbitmq"
        RETAIL_ORDERS_MESSAGING_RABBITMQ_ADDRESSES = "amqps://${var.mq_endpoint}:5671"
        RETAIL_ORDERS_MESSAGING_RABBITMQ_USERNAME  = var.mq_username
        RETAIL_ORDERS_MESSAGING_RABBITMQ_PASSWORD  = var.mq_password
        RETAIL_ORDERS_PERSISTENCE_PROVIDER         = "postgres"
        RETAIL_ORDERS_PERSISTENCE_ENDPOINT         = var.orders_db_secrets.host
        RETAIL_ORDERS_PERSISTENCE_NAME             = var.orders_db_secrets.database
        RETAIL_ORDERS_PERSISTENCE_USERNAME         = var.orders_db_secrets.username
        RETAIL_ORDERS_PERSISTENCE_PASSWORD         = var.orders_db_secrets.password
      }
      health_path      = "/health"
      task_policy_arns = []
    }

    ui = {
      name   = "ui"
      port   = 8080
      cpu    = 512
      memory = 1024
      environment = {
        RETAIL_UI_ENDPOINTS_CATALOG  = "http://catalog.${local.service_discovery_namespace}:8080"
        RETAIL_UI_ENDPOINTS_CARTS    = "http://cart.${local.service_discovery_namespace}:8080"
        RETAIL_UI_ENDPOINTS_CHECKOUT = "http://checkout.${local.service_discovery_namespace}:8080"
        RETAIL_UI_ENDPOINTS_ORDERS   = "http://orders.${local.service_discovery_namespace}:8080"
      }
      health_path      = "/actuator/health"
      task_policy_arns = []
    }
  }

  service_discovery_namespace = "retailstore.local"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/${var.environment_name}"

  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${var.environment_name}-log-group" })
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = local.service_discovery_namespace
  description = "Service discovery namespace for ${var.environment_name}"
  vpc         = var.vpc_id
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.container_insights_setting
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-cluster" })
}

# IAM Roles para ECS
resource "aws_iam_role" "task_execution" {
  name = "${var.environment_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy adicional para ECR
resource "aws_iam_policy" "ecr_access" {
  name = "${var.environment_name}-ecr-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role" "task" {
  name = "${var.environment_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# Policy para CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs" {
  name = "${var.environment_name}-cloudwatch-logs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups"
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.environment_name}:*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Policy para ECS Exec (debugging)
resource "aws_iam_policy" "ecs_exec" {
  name = "${var.environment_name}-ecs-exec-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.ecs_exec.arn
}

# Task role - DynamoDB policy
resource "aws_iam_role_policy_attachment" "dynamodb" {
  count      = length(var.dynamodb_policy_arn) > 0 ? 1 : 0
  role       = aws_iam_role.task.name
  policy_arn = var.dynamodb_policy_arn
}

# Service Discovery Services
resource "aws_service_discovery_service" "this" {
  for_each = local.services

  name = each.value.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = merge(var.tags, { Service = each.value.name })
}

# Task Definitions
resource "aws_ecs_task_definition" "this" {
  for_each = local.services

  family                   = "${var.environment_name}-${each.value.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name  = "${each.value.name}-container"
    image = local.images[each.key]

    portMappings = [{
      containerPort = each.value.port
      hostPort      = each.value.port
      protocol      = "tcp"
    }]

    essential = true

    environment = [
      for key, value in each.value.environment : {
        name  = key
        value = value
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = each.value.name
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}${each.value.health_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = merge(var.tags, { Service = each.value.name })
}

# ECS Services
resource "aws_ecs_service" "this" {
  for_each = local.services

  name                   = each.value.name
  cluster                = aws_ecs_cluster.this.arn
  task_definition        = aws_ecs_task_definition.this[each.key].arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this[each.key].arn
  }

  dynamic "load_balancer" {
    for_each = each.key == "ui" && var.alb_target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = "${each.value.name}-container"
      container_port   = each.value.port
    }
  }

  tags = merge(var.tags, { Service = each.value.name })

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Auto Scaling Target para cada servicio
resource "aws_appautoscaling_target" "ecs" {
  for_each = local.services

  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${each.value.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.this]
}

# Auto Scaling Policy - CPU Target Tracking (escala cuando CPU > 87%)
resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.services

  name               = "${var.environment_name}-${each.value.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 87.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory Target Tracking (escala cuando Memory > 90%)
resource "aws_appautoscaling_policy" "memory" {
  for_each = local.services

  name               = "${var.environment_name}-${each.value.name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 90.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Outputs
output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.this.arn
}

output "service_discovery_namespace" {
  description = "Namespace de Service Discovery"
  value       = local.service_discovery_namespace
}

output "log_group_name" {
  description = "Nombre del Log Group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "task_execution_role_arn" {
  description = "ARN del rol de ejecución de tareas"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN del rol de tareas"
  value       = aws_iam_role.task.arn
}

output "service_urls" {
  description = "URLs de los servicios (internas)"
  value = {
    catalog  = "http://catalog.${local.service_discovery_namespace}:8080"
    cart     = "http://cart.${local.service_discovery_namespace}:8080"
    checkout = "http://checkout.${local.service_discovery_namespace}:8080"
    orders   = "http://orders.${local.service_discovery_namespace}:8080"
    ui       = "http://ui.${local.service_discovery_namespace}:8080"
  }
}

output "service_arns" {
  description = "ARNs de los servicios ECS"
  value = {
    for name, service in aws_ecs_service.this : name => service.id
  }
}
