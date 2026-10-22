# =====================================================================
# 02-plataforma · bases de datos RDS PostgreSQL
#
# Una instancia por servicio (producerdb y consumerdb), Single-AZ por costo.
# Preparadas para alta disponibilidad:
#   - el grupo de subredes ya cubre 2 zonas
#   - cada base queda en una zona distinta (producer en a, consumer en b)
#   - db_multi_az = true agrega la réplica en espera sin cambiar el código
# =====================================================================

# Versión exacta de PostgreSQL a partir de la indicada (por ejemplo 18 -> 18.x)
data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = var.db_engine_version
  latest  = true
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-data"
  description = "Subredes privadas de datos en ${join(", ", var.availability_zones)}"
  subnet_ids  = [for s in aws_subnet.data : s.id]

  tags = {
    Name = "${local.name_prefix}-data"
  }
}

resource "aws_db_instance" "this" {
  for_each = var.databases

  # Nombre de la instancia: uceshop-academy-producerdb
  identifier = "${local.name_prefix}-${each.value.db_name}"

  # Motor y tamaño
  engine                     = "postgres"
  engine_version             = data.aws_rds_engine_version.postgres.version_actual
  instance_class             = var.db_instance_class
  auto_minor_version_upgrade = var.db_auto_minor_version_upgrade

  # Disco
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = var.db_storage_type
  storage_encrypted     = var.db_storage_encrypted

  # Base de datos y usuario maestro
  db_name  = each.value.db_name
  username = each.value.username
  password = random_password.this["${each.key}_db_password"].result
  port     = var.service_ports.postgres

  # Red: privada, solo su security group
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this["rds_${each.key}"].id]
  publicly_accessible    = false

  # Alta disponibilidad: con Multi-AZ AWS elige las zonas; sin Multi-AZ,
  # cada base va a su zona preferida para no concentrar el riesgo.
  multi_az          = var.db_multi_az
  availability_zone = var.db_multi_az ? null : element(var.availability_zones, each.value.az_index)

  # Copias y mantenimiento
  backup_retention_period = var.db_backup_retention_days
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window
  copy_tags_to_snapshot   = true

  # Ciclo de vida (valores de laboratorio; en producción, al revés)
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name_prefix}-${each.value.db_name}-final"
  apply_immediately         = true

  tags = {
    Name    = "${local.name_prefix}-${each.value.db_name}"
    Service = "${each.key}-service"
  }
}
