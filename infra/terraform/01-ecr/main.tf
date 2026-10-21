# =====================================================================
# 01-ecr · repositorios de imágenes
#
# Crea un repositorio por servicio: uceshop/producer-service,
# uceshop/consumer-service, ... (8 en total).
# Esta etapa se crea una vez y se conserva hasta el final del proyecto.
# =====================================================================

# Datos de la cuenta actual (se usan para armar la dirección del registro)
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------
# Repositorios
# for_each crea un repositorio por cada nombre de var.repositories
# ---------------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name = "${var.project}/${each.value}"

  # MUTABLE: permite volver a subir la misma etiqueta (por ejemplo 1.0.0)
  # si corriges algo durante las pruebas.
  image_tag_mutability = "MUTABLE"

  # Permite que "terraform destroy" borre el repositorio aunque tenga imágenes
  force_delete = true

  # Analiza vulnerabilidades cada vez que subes una imagen (gratis)
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------------------
# Política de retención: conserva solo las últimas N imágenes por repositorio
# ---------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las ultimas ${var.images_to_keep} imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.images_to_keep
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
