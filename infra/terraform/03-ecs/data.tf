# =====================================================================
# 03-ecs · recursos que ya existen (01-ecr y 02-plataforma)
# Se buscan por nombre: si algo falta, terraform plan falla aquí, antes
# de crear nada.
# =====================================================================

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  filter {
    name   = "tag:Tier"
    values = ["public"]
  }
}

data "aws_security_group" "this" {
  for_each = toset(values(local.service_security_group))

  vpc_id = data.aws_vpc.this.id
  name   = "${local.name_prefix}-${each.key}"
}

data "aws_ecs_cluster" "this" {
  cluster_name = local.name_prefix
}

data "aws_db_instance" "this" {
  for_each = var.databases

  db_instance_identifier = "${local.name_prefix}-${each.value}"
}

# Solo se lee el ARN; la contraseña no se descifra aquí
data "aws_ssm_parameter" "secret" {
  for_each = toset(concat(
    [for k in keys(var.databases) : "${k}-db-password"],
    ["rabbitmq-password", "grafana-admin-password"],
  ))

  name            = "${local.ssm_prefix}/${each.key}"
  with_decryption = false
}

# Comprueba que cada imagen exista en ECR con su etiqueta
data "aws_ecr_image" "this" {
  for_each = local.ecr_images_to_check

  repository_name = "${var.ecr_repository_prefix}/${each.key}"
  image_tag       = each.value
}