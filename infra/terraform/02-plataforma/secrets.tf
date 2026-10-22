# =====================================================================
# 02-plataforma · contraseñas
#
# Terraform genera contraseñas aleatorias y las guarda cifradas en
# SSM Parameter Store (SecureString). Las tareas ECS las leerán de ahí.
# ATENCIÓN: también quedan en terraform.tfstate. Nunca subas ese archivo.
# =====================================================================

locals {
  # Una contraseña por base de datos + RabbitMQ + Grafana
  secrets = merge(
    { for k, db in var.databases : "${k}_db_password" => "Password del usuario maestro de ${db.db_name}" },
    {
      rabbitmq_password      = "Password del usuario de RabbitMQ"
      grafana_admin_password = "Password del administrador de Grafana"
    },
  )
}

resource "random_password" "this" {
  for_each = local.secrets

  length = var.password_length

  # Sin / @ " ni espacios: RDS no los acepta
  special          = true
  override_special = "-_!#%*+="
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
}

resource "aws_ssm_parameter" "secret" {
  for_each = local.secrets

  # Ejemplo: /uceshop/academy/producer-db-password
  name        = "${local.ssm_prefix}/${replace(each.key, "_", "-")}"
  description = each.value
  type        = "SecureString"
  value       = random_password.this[each.key].result

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  }
}
