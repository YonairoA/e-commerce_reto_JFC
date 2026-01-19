module "tags" {
  source = "./modules/tags"

  environment_name = var.environment_name
}

# MÓDULO ECR - Repositorios de Imágenes de Contenedores
# Debe crearse primero para poder subir las imágenes
module "ecr" {
  source = "./modules/ecr"

  environment_name       = var.environment_name
  repository_names       = ["ui", "catalog", "cart", "checkout", "orders"]
  image_tag_mutability   = "MUTABLE"
  scan_on_push           = true
  lifecycle_policy_count = 10

  tags = module.tags.result
}

# MÓDULO VPC - Red Virtual con NAT Gateway
module "vpc" {
  source = "./modules/vpc"

  environment_name = var.environment_name
  vpc_cidr         = var.vpc_cidr

  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets

  create_igw         = true
  enable_nat_gateway = true

  tags = module.tags.result
}

# MÓDULO SECURITY GROUPS - Grupos de Seguridad
module "security_groups" {
  source = "./modules/security-groups"

  environment_name = var.environment_name
  vpc_id           = module.vpc.vpc_id

  tags = module.tags.result
}

# MÓDULO AURORA SERVERLESS v2 - Microservicio CATALOG (MySQL)
# Base de datos para el catálogo de productos
module "aurora_catalog" {
  source = "./modules/aurora-serverless"

  environment_name = var.environment_name
  engine           = "aurora-mysql"
  identifier       = "${var.environment_name}-catalog"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.aurora]

  serverless_v2_scaling_configuration = {
    max_capacity = 16
    min_capacity = 0.5
  }

  database_name   = var.catalog_db_name
  master_username = var.catalog_db_username
  master_password = var.catalog_db_password

  deletion_protection = var.deletion_protection

  tags = module.tags.result
}

# MÓDULO AURORA SERVERLESS v2 - Microservicio ORDERS (PostgreSQL)
# Base de datos para las órdenes de compra
module "aurora_orders" {
  source = "./modules/aurora-serverless"

  environment_name = var.environment_name
  engine           = "aurora-postgresql"
  identifier       = "${var.environment_name}-orders"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.aurora]

  serverless_v2_scaling_configuration = {
    max_capacity = 16
    min_capacity = 0.5
  }

  database_name   = var.orders_db_name
  master_username = var.orders_db_username
  master_password = var.orders_db_password

  deletion_protection = var.deletion_protection

  tags = module.tags.result
}

# MÓDULO DYNAMODB ON-DEMAND - Microservicio CARTS
# Tabla NoSQL para el carrito de compras
module "dynamodb_carts" {
  source = "./modules/dynamodb"

  environment_name = var.environment_name
  table_name       = "${var.environment_name}-carts"

  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST" # On-demand para tráfico variable

  attributes = [
    { name = "id", type = "S" },
    { name = "customerId", type = "S" }
  ]

  global_secondary_indexes = [{
    name            = "idx_customer_id"
    hash_key        = "customerId"
    projection_type = "ALL"
  }]

  tags = module.tags.result
}

# MÓDULO ELASTICACHE  - Microservicio CHECKOUT
module "elasticache_checkout" {
  source = "./modules/elasticache"

  environment_name = var.environment_name
  identifier       = "${var.environment_name}-checkout"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.elasticache]

  node_type = "cache.t3.micro"
  num_nodes = 1

  tags = module.tags.result
}

# Message broker para procesamiento asíncrono de órdenes
module "mq_orders" {
  source = "./modules/mq-rabbitmq"

  environment_name = var.environment_name
  identifier       = "${var.environment_name}-mq"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = [module.vpc.private_subnet_ids[0]]
  security_group_ids = [module.security_groups.mq]

  engine_type        = "RabbitMQ"
  engine_version     = "3.13"
  host_instance_type = "mq.t3.micro"
  deployment_mode    = "SINGLE_INSTANCE"

  admin_username = var.mq_admin_username
  admin_password = var.mq_admin_password

  tags = module.tags.result
}

# MÓDULO ALB - Application Load Balancer
# Punto de entrada público para la interfaz de usuario
module "alb" {
  source = "./modules/alb"

  environment_name = var.environment_name

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnet_ids
  security_groups = [module.security_groups.alb]

  tags = module.tags.result
}

# MÓDULO ECS - Cluster y Servicios con Fargate
# Orquestación de contenedores para todos los microservicios
module "ecs" {
  source = "./modules/ecs"

  environment_name  = var.environment_name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids

  cluster_name               = "${var.environment_name}-cluster"
  container_insights_setting = var.container_insights_setting
  log_retention_days         = var.log_retention_days

  # Secrets para bases de datos
  catalog_db_secrets = {
    host     = module.aurora_catalog.endpoint
    port     = tostring(module.aurora_catalog.port)
    username = module.aurora_catalog.master_username
    password = module.aurora_catalog.master_password
    database = module.aurora_catalog.database_name
  }

  orders_db_secrets = {
    host     = module.aurora_orders.endpoint
    port     = tostring(module.aurora_orders.port)
    username = module.aurora_orders.master_username
    password = module.aurora_orders.master_password
    database = module.aurora_orders.database_name
  }

  # DynamoDB
  dynamodb_table_name = module.dynamodb_carts.table_name
  dynamodb_policy_arn = module.dynamodb_carts.policy_arn

  # Redis/Valkey
  redis_endpoint = module.elasticache_checkout.cluster_address
  redis_port     = tostring(module.elasticache_checkout.port)

  # MQ RabbitMQ
  mq_endpoint = module.mq_orders.endpoint
  mq_username = module.mq_orders.admin_username
  mq_password = module.mq_orders.admin_password

  # ALB
  alb_target_group_arn  = module.alb.target_group_arns[0]
  alb_security_group_id = module.security_groups.alb

  # Security Group para servicios ECS (del módulo security-groups)
  ecs_security_group_id = module.security_groups.ecs

  # Imágenes de contenedores desde ECR
  container_image_overrides = {
    ui       = var.container_image_overrides.ui != null ? var.container_image_overrides.ui : module.ecr.image_uris["ui"]
    catalog  = var.container_image_overrides.catalog != null ? var.container_image_overrides.catalog : module.ecr.image_uris["catalog"]
    cart     = var.container_image_overrides.cart != null ? var.container_image_overrides.cart : module.ecr.image_uris["cart"]
    checkout = var.container_image_overrides.checkout != null ? var.container_image_overrides.checkout : module.ecr.image_uris["checkout"]
    orders   = var.container_image_overrides.orders != null ? var.container_image_overrides.orders : module.ecr.image_uris["orders"]
  }

  tags = module.tags.result

  depends_on = [module.ecr]
}

# MÓDULO CLOUDWATCH - Alarmas y Monitoreo
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment_name = var.environment_name
  cluster_name     = module.ecs.cluster_name
  service_names    = ["ui", "catalog", "cart", "checkout", "orders"]

  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  cpu_threshold_warning    = 70
  memory_threshold_warning = 80
  response_time_threshold  = 2
  error_5xx_threshold      = 10

  tags = module.tags.result
}
