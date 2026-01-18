# Alarmas y métricas para monitoreo del e-commerce

variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "cluster_name" {
  type        = string
  description = "Nombre del cluster ECS"
}

variable "service_names" {
  type        = list(string)
  description = "Lista de nombres de servicios ECS"
  default     = ["ui", "catalog", "cart", "checkout", "orders"]
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix del ALB"
}

variable "target_group_arn_suffix" {
  type        = string
  description = "ARN suffix del Target Group"
}

variable "cpu_threshold_warning" {
  type        = number
  description = "Umbral de CPU para alarma warning"
  default     = 88
}

variable "memory_threshold_warning" {
  type        = number
  description = "Umbral de memoria para alarma warning"
  default     = 95
}

variable "response_time_threshold" {
  type        = number
  description = "Umbral de tiempo de respuesta en segundos"
  default     = 2
}

variable "error_5xx_threshold" {
  type        = number
  description = "Umbral de errores 5XX en período de evaluación"
  default     = 10
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN del SNS Topic para notificaciones (opcional)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Alarma CPU > 88% por servicio ECS
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_warning" {
  for_each = toset(var.service_names)

  alarm_name          = "${var.environment_name}-${each.value}-cpu-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_threshold_warning
  alarm_description   = "CPU del servicio ${each.value} supera ${var.cpu_threshold_warning}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Service  = each.value
    Severity = "warning"
  })
}

# Alarma Memory > 95% por servicio ECS
resource "aws_cloudwatch_metric_alarm" "ecs_memory_warning" {
  for_each = toset(var.service_names)

  alarm_name          = "${var.environment_name}-${each.value}-memory-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_threshold_warning
  alarm_description   = "Memoria del servicio ${each.value} supera ${var.memory_threshold_warning}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Service  = each.value
    Severity = "warning"
  })
}

# Alarma TargetResponseTime > 2s en ALB
resource "aws_cloudwatch_metric_alarm" "alb_response_time_warning" {
  alarm_name          = "${var.environment_name}-alb-response-time-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.response_time_threshold
  alarm_description   = "Tiempo de respuesta del ALB supera ${var.response_time_threshold} segundos"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

# Alarma HTTPCode_Target_5XX_Count > 10 en 5 min
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.environment_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "Errores 5XX superan ${var.error_5xx_threshold} en 5 minutos"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Severity = "critical"
  })
}

# Outputs
output "cpu_alarm_arns" {
  description = "ARNs de las alarmas de CPU"
  value = {
    for name, alarm in aws_cloudwatch_metric_alarm.ecs_cpu_warning : name => alarm.arn
  }
}

output "memory_alarm_arns" {
  description = "ARNs de las alarmas de memoria"
  value = {
    for name, alarm in aws_cloudwatch_metric_alarm.ecs_memory_warning : name => alarm.arn
  }
}

output "alb_response_time_alarm_arn" {
  description = "ARN de la alarma de tiempo de respuesta"
  value       = aws_cloudwatch_metric_alarm.alb_response_time_warning.arn
}

output "alb_5xx_alarm_arn" {
  description = "ARN de la alarma de errores 5XX"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
}
