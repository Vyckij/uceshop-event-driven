# =====================================================================
# 02-plataforma · valores calculados (no se editan; salen de las variables)
# =====================================================================

locals {
  # Prefijo de todos los nombres: uceshop-academy-...
  name_prefix = "${var.project}-${var.environment}"

  # Ruta de los parámetros en SSM: /uceshop/academy/...
  ssm_prefix = "/${var.project}/${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Stage       = "02-plataforma"
      ManagedBy   = "terraform"
    },
    var.extra_tags,
  )

  # Letra de cada zona: us-east-1a -> a
  az_suffix = { for az in var.availability_zones : az => trimprefix(az, var.aws_region) }

  # Subredes como mapas con nombre estable: public-a, public-b, data-a, data-b
  public_subnets = {
    for i, az in var.availability_zones :
    "public-${local.az_suffix[az]}" => { az = az, cidr = var.public_subnet_cidrs[i] }
  }

  data_subnets = {
    for i, az in var.availability_zones :
    "data-${local.az_suffix[az]}" => { az = az, cidr = var.data_subnet_cidrs[i] }
  }
}
