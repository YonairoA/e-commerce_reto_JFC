# MÓDULO ECR - Repositorios de Imágenes de Contenedores
# Para almacenar las imágenes Docker de los microservicios
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "repository_names" {
  type        = list(string)
  description = "Lista de nombres de repositorios a crear"
  default     = ["ui", "catalog", "cart", "checkout", "orders"]
}

variable "image_tag_mutability" {
  type        = string
  description = "Mutabilidad de tags (MUTABLE o IMMUTABLE)"
  default     = "MUTABLE"
}

variable "scan_on_push" {
  type        = bool
  description = "Escanear imágenes al hacer push"
  default     = true
}

variable "force_delete" {
  type        = bool
  description = "Permitir eliminar repositorio con imágenes"
  default     = false
}

variable "lifecycle_policy_count" {
  type        = number
  description = "Cantidad de imágenes a retener"
  default     = 10
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# Mapeo de nombres de repositorio a nombres de imágenes locales
locals {
  image_map = {
    "ui"       = "pragma-ui-jfc:latest"
    "catalog"  = "pragma-catalog-jfc:latest"
    "cart"     = "pragma-cart-jfc:latest"
    "checkout" = "pragma-checkout-jfc:latest"
    "orders"   = "pragma-orders-jfc:latest"
  }
}

# Repositorios ECR
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = "${var.environment_name}-${each.value}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name         = "${var.environment_name}-${each.value}"
    Microservice = each.value
  })
}

# Política de Ciclo de Vida (retener últimas N imágenes)
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener las últimas ${var.lifecycle_policy_count} imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.lifecycle_policy_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Política de Repositorio (permitir acceso desde la cuenta)
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecr_repository_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# Outputs
output "repository_urls" {
  description = "URLs de los repositorios ECR"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "repository_arns" {
  description = "ARNs de los repositorios ECR"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.arn
  }
}

output "repository_names" {
  description = "Nombres de los repositorios ECR"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.name
  }
}

output "registry_id" {
  description = "ID del registro ECR (AWS Account ID)"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Región de AWS"
  value       = data.aws_region.current.name
}

# Output con las URIs completas de las imágenes (con tag :latest)
output "image_uris" {
  description = "URIs de las imágenes con tag latest"
  value = {
    for name, repo in aws_ecr_repository.this : name => "${repo.repository_url}:latest"
  }
}

# Push automático de imágenes locales a ECR
resource "null_resource" "push_images" {
  for_each = aws_ecr_repository.this

  provisioner "local-exec" {
    command = <<-EOF
      echo "Enviando ${each.key} imagen a ECR..."
      
      # Login a ECR
      aws ecr get-login-password --region ${data.aws_region.current.name} | \
        docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com
      
      # Tag de la imagen local
      docker tag ${local.image_map[each.key]} ${each.value.repository_url}:latest
      
      # Push a ECR
      docker push ${each.value.repository_url}:latest
      
      echo "Push correcto ${each.key} a ECR"
    EOF
  }

  depends_on = [
    aws_ecr_repository.this,
    aws_ecr_repository_policy.this
  ]

  triggers = {
    repository_url = each.value.repository_url
  }
}
