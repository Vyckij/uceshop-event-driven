# =====================================================================
# 02-plataforma · salidas (terraform output)
# La fase de servicios ECS usará estos valores.
# =====================================================================

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "availability_zones" {
  description = "Zonas usadas"
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "Subredes públicas por nombre (public-a, public-b)"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "data_subnet_ids" {
  description = "Subredes privadas de datos por nombre (data-a, data-b)"
  value       = { for k, s in aws_subnet.data : k => s.id }
}

output "security_group_ids" {
  description = "Security groups por componente"
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}



output "ecs_cluster" {
  description = "Clúster ECS"
  value = {
    name = aws_ecs_cluster.this.name
    arn  = aws_ecs_cluster.this.arn
  }
}

output "db_engine_version_resolved" {
  description = "Versión exacta de PostgreSQL usada (fíjala en terraform.tfvars para que no cambie)"
  value       = data.aws_rds_engine_version.postgres.version_actual
}

output "databases" {
  description = "Datos de conexión de cada base (sin contraseñas)"
  value = {
    for k, db in aws_db_instance.this : k => {
      host              = db.address
      port              = db.port
      db_name           = db.db_name
      username          = db.username
      availability_zone = db.availability_zone
      multi_az          = db.multi_az
    }
  }
}

output "ssm_parameters" {
  description = "Nombres de los parámetros SSM con las contraseñas (los valores no se muestran)"
  value       = { for k, p in aws_ssm_parameter.secret : k => p.name }
}
