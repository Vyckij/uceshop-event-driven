# =====================================================================
# 02-plataforma · red
#
# VPC en 2 zonas:
#   public-a / public-b : tareas ECS, ALB interno y VPC Link (fases siguientes)
#   data-a   / data-b   : RDS, sin ruta a internet
# =====================================================================

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Necesarios para el DNS privado de Cloud Map (uceshop.local)
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ---------------------------------------------------------------------
# Subredes públicas (una por zona)
# ---------------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  # ECS asignará la IP pública tarea por tarea (assign_public_ip),
  # así nada recibe IP pública por accidente.
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = "public"
  }
}

# ---------------------------------------------------------------------
# Subredes privadas de datos (una por zona)
# ---------------------------------------------------------------------
resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = "data"
  }
}

# ---------------------------------------------------------------------
# Tablas de rutas
# ---------------------------------------------------------------------

# Pública: todo lo que no es de la VPC sale por el Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Datos: solo la ruta local de la VPC (sin salida a internet)
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-data-rt"
  }
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}
