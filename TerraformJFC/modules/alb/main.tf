# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "subnets" {
  type        = list(string)
  description = "IDs de las subnets públicas"
}

variable "security_groups" {
  type        = list(string)
  description = "Security groups"
}

variable "lb_name" {
  type        = string
  description = "Nombre del ALB"
  default     = null
}

variable "internal" {
  type        = bool
  description = "Si es interno o público"
  default     = false
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Habilitar protección contra eliminación"
  default     = false
}

variable "idle_timeout" {
  type        = number
  description = "Timeout de inactividad en segundos"
  default     = 60
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Application Load Balancer
resource "aws_lb" "this" {
  name                       = var.lb_name != null ? var.lb_name : "${var.environment_name}-alb"
  internal                   = var.internal
  load_balancer_type         = "application"
  security_groups            = var.security_groups
  subnets                    = var.subnets
  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  tags = merge(var.tags, { Name = "${var.environment_name}-alb" })
}

# Target Group para UI
resource "aws_lb_target_group" "ui" {
  name        = "${var.environment_name}-ui-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Stickiness para sesiones
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-ui-tg" })
}

# Listener HTTP (puerto 80) - Redirige a UI
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-http-listener" })
}

# Outputs
output "id" {
  description = "ID del ALB"
  value       = aws_lb.this.id
}

output "arn" {
  description = "ARN del ALB"
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix del ALB"
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "DNS name del ALB (URL de acceso)"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Zone ID del ALB"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "ARNs de los target groups"
  value       = [aws_lb_target_group.ui.arn]
}

output "target_group_id" {
  description = "ID del target group de UI"
  value       = aws_lb_target_group.ui.id
}

output "target_group_arn_suffix" {
  description = "ARN suffix del target group de UI (para CloudWatch)"
  value       = aws_lb_target_group.ui.arn_suffix
}

output "listener_arn" {
  description = "ARN del listener HTTP"
  value       = aws_lb_listener.http.arn
}

output "url" {
  description = "URL completa para acceder a la aplicación"
  value       = "http://${aws_lb.this.dns_name}"
}
