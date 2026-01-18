# Se definen las reglas de firewall para cada componente de la arquitectura
# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC para reglas internas"
  default     = "10.0.0.0/16"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Security Group para ALB (público - puertos 80/443)
resource "aws_security_group" "alb" {
  name        = "${var.environment_name}-alb-sg"
  description = "Security group para el Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP desde internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS desde internet"
  }

  # Outbound: hacia servicios ECS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Todo trafico saliente"
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-alb-sg" })
}

# Security Group para ECS Services (puerto 8080)
resource "aws_security_group" "ecs" {
  name        = "${var.environment_name}-ecs-sg"
  description = "Security group para los servicios ECS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Desde ALB"
  }

  # Inbound: desde otros servicios ECS (comunicación interna)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
    description = "Comunicacion entre servicios ECS"
  }

  # Inbound: comunicación interna VPC
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Comunicacion interna VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Todo trafico saliente"
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-ecs-sg" })
}

# Security Group para Aurora (MySQL/PostgreSQL)
resource "aws_security_group" "aurora" {
  name        = "${var.environment_name}-aurora-sg"
  description = "Security group para Aurora Serverless v2"
  vpc_id      = var.vpc_id

  # Inbound: MySQL desde ECS
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "MySQL desde ECS"
  }

  # Inbound: PostgreSQL desde ECS
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "PostgreSQL desde ECS"
  }

  # Outbound: limitado
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Todo trafico saliente"
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-aurora-sg" })
}

# Security Group para ElastiCache (Redis/Valkey)
resource "aws_security_group" "elasticache" {
  name        = "${var.environment_name}-elasticache-sg"
  description = "Security group para ElastiCache Valkey"
  vpc_id      = var.vpc_id

  # Inbound: Redis desde ECS
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "Redis/Valkey desde ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Todo trafico saliente"
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-elasticache-sg" })
}

# Security Group para MQ (RabbitMQ)
resource "aws_security_group" "mq" {
  name        = "${var.environment_name}-mq-sg"
  description = "Security group para Amazon MQ RabbitMQ"
  vpc_id      = var.vpc_id

  # Inbound: AMQP con TLS desde ECS
  ingress {
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "AMQP+TLS desde ECS"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "Management UI HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Todo trafico saliente"
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-mq-sg" })
}

# Outputs - Devuelven IDs de los Security Groups
output "alb" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

output "ecs" {
  description = "ID del Security Group de los servicios ECS"
  value       = aws_security_group.ecs.id
}

output "aurora" {
  description = "ID del Security Group de Aurora"
  value       = aws_security_group.aurora.id
}

output "elasticache" {
  description = "ID del Security Group de ElastiCache"
  value       = aws_security_group.elasticache.id
}

output "mq" {
  description = "ID del Security Group de MQ"
  value       = aws_security_group.mq.id
}

# Outputs adicionales con objetos completos
output "all" {
  description = "Todos los Security Groups"
  value = {
    alb         = aws_security_group.alb
    ecs         = aws_security_group.ecs
    aurora      = aws_security_group.aurora
    elasticache = aws_security_group.elasticache
    mq          = aws_security_group.mq
  }
}
