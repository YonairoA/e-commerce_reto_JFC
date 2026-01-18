# Para el microservicio del carrito de compras
# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "table_name" {
  type        = string
  description = "Nombre de la tabla"
}

variable "hash_key" {
  type        = string
  description = "Nombre del atributo de hash key"
  default     = "id"
}

variable "range_key" {
  type        = string
  description = "Nombre del atributo de range key (opcional)"
  default     = null
}

variable "billing_mode" {
  type        = string
  description = "Modo de facturación (PAY_PER_REQUEST o PROVISIONED)"
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  type        = number
  description = "Read capacity units (solo para PROVISIONED)"
  default     = 5
}

variable "write_capacity" {
  type        = number
  description = "Write capacity units (solo para PROVISIONED)"
  default     = 5
}

variable "attributes" {
  type = list(object({
    name = string
    type = string
  }))
  description = "Lista de atributos"
  default = [
    { name = "id", type = "S" }
  ]
}

variable "global_secondary_indexes" {
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = string
    non_key_attributes = optional(list(string))
  }))
  description = "Índices secundarios globales"
  default     = []
}

variable "stream_enabled" {
  type        = bool
  description = "Habilitar DynamoDB Streams"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Tabla DynamoDB
resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode

  # Capacidad (solo para PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Hash key
  hash_key  = var.hash_key
  range_key = var.range_key

  # Atributos
  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = try(global_secondary_index.value.range_key, null)
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = try(global_secondary_index.value.non_key_attributes, null)
    }
  }

  # DynamoDB Streams
  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? "NEW_AND_OLD_IMAGES" : null

  # Cifrado en reposo
  server_side_encryption {
    enabled = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, { Name = var.table_name })
}

# IAM Policy para acceso a DynamoDB
resource "aws_iam_policy" "this" {
  name = "${var.environment_name}-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.this.arn,
          "${aws_dynamodb_table.this.arn}/index/*"
        ]
      }
    ]
  })

  tags = var.tags
}

# Outputs
output "id" {
  description = "ID de la tabla"
  value       = aws_dynamodb_table.this.id
}

output "arn" {
  description = "ARN de la tabla"
  value       = aws_dynamodb_table.this.arn
}

output "table_name" {
  description = "Nombre de la tabla"
  value       = aws_dynamodb_table.this.name
}

output "policy_arn" {
  description = "ARN del policy de IAM"
  value       = aws_iam_policy.this.arn
}

output "stream_arn" {
  description = "ARN del stream (si está habilitado)"
  value       = try(aws_dynamodb_table.this.stream_arn, null)
}
