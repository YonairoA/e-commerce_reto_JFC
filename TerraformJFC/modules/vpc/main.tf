# MÓDULO VPC - Virtual Private Cloud con NAT Gateway
# Variables de Entrada
variable "environment_name" {
  type        = string
  description = "Nombre del entorno"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Lista de Zonas de Disponibilidad"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnets" {
  type        = list(string)
  description = "CIDRs de subnets privadas"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDRs de subnets públicas"
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "create_igw" {
  type        = bool
  description = "Crear Internet Gateway"
  default     = true
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Habilitar NAT Gateway"
  default     = true # Siempre habilitado
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}

# VPC
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.environment_name}-vpc" })
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.environment_name}-igw" })
}

# Subnets Públicas
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name       = "${var.environment_name}-public-${var.availability_zones[count.index]}"
    SubnetType = "public"
  })
}

# Subnets Privadas
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name       = "${var.environment_name}-private-${var.availability_zones[count.index]}"
    SubnetType = "private"
  })
}

# Elastic IP para NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.environment_name}-nat-eip" })

  depends_on = [aws_internet_gateway.this]
}

# NAT Gateway (en la primera subnet pública)
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, { Name = "${var.environment_name}-nat" })

  depends_on = [aws_internet_gateway.this]
}

# Route Table Pública (hacia Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-public-rt" })
}

# Route Table Privada (hacia NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.environment_name}-private-rt" })
}

# Route Table Associations - Públicas
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

# Route Table Associations - Privadas
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

# Outputs
output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = aws_vpc.this.cidr_block
}

output "igw_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway"
  value       = aws_nat_gateway.this.id
}

output "nat_gateway_public_ip" {
  description = "IP pública del NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID de la route table pública"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID de la route table privada"
  value       = aws_route_table.private.id
}

output "availability_zones" {
  description = "Lista de AZs utilizadas"
  value       = var.availability_zones
}
