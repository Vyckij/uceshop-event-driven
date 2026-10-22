# =====================================================================
# 02-plataforma · versiones de Terraform y proveedores
# =====================================================================

terraform {
  # 1.10 o superior: las validaciones de variables comparan entre variables
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Las credenciales salen de ~/.aws/credentials (AWS Details en Learner Lab).
# Cambiar de cuenta o de laboratorio = cambiar ese archivo, no este código.
provider "aws" {
  region = var.aws_region

  # Etiquetas comunes para TODOS los recursos (definidas en locals.tf)
  default_tags {
    tags = local.common_tags
  }
}
