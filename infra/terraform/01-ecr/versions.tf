# =====================================================================
# 01-ecr · versiones de Terraform y del proveedor AWS
# =====================================================================

terraform {
  # Cualquier Terraform 1.x desde la 1.10 (la actual es 1.16)
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # cualquier 6.x, nunca la 7.0
    }
  }
}

# El proveedor toma las credenciales del archivo ~/.aws/credentials
# (las que copias de "AWS Details" en Learner Lab).
provider "aws" {
  region = var.aws_region

  # Etiquetas que se agregan a TODOS los recursos de esta etapa
  default_tags {
    tags = {
      Project     = var.project
      Stage       = "01-ecr"
      Environment = "aws-academy"
      ManagedBy   = "terraform"
    }
  }
}
