# =====================================================================
# 03-ecs · valores calculados
# =====================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
  ssm_prefix  = "/${var.project}/${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Stage       = "03-ecs"
      ManagedBy   = "terraform"
    },
    var.extra_tags,
  )

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # 042064121896.dkr.ecr.us-east-1.amazonaws.com/uceshop/<repo>:<tag>
  ecr_registry = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  images = merge(
    {
      for repo, tag in var.image_tags :
      repo => "${local.ecr_registry}/${var.ecr_repository_prefix}/${repo}:${tag}"
    },
    var.image_overrides,
  )

  # Imágenes que se comprueban en ECR (las reemplazadas no)
  ecr_images_to_check = {
    for repo, tag in var.image_tags : repo => tag
    if !contains(keys(var.image_overrides), repo)
  }

  # Security group de 02-plataforma que usa cada servicio
  service_security_group = {
    "kafka"            = "kafka"
    "rabbitmq"         = "rabbitmq"
    "producer-service" = "producer"
    "consumer-service" = "consumer"
    "prometheus"       = "prometheus"
    "grafana"          = "grafana"
    "dashboard"        = "dashboard"
  }

  # paused = true apaga todas las tareas sin borrar nada
  desired_count = { for k, s in var.services : k => var.paused ? 0 : s.desired_count }

  public_subnet_ids = sort(data.aws_subnets.public.ids)

  # DNS de la VPC (dirección .2 del rango): lo usa Nginx del dashboard
  vpc_dns_resolver = cidrhost(data.aws_vpc.this.cidr_block, 2)

  # ARN de cada contraseña en SSM
  secret_arn = { for k, p in data.aws_ssm_parameter.secret : k => p.arn }

  # URL JDBC con SSL (RDS PostgreSQL 18 rechaza conexiones sin cifrar)
  jdbc_url = {
    for k, db in data.aws_db_instance.this :
    k => "jdbc:postgresql://${db.address}:${db.port}/${db.db_name}?sslmode=${var.db_sslmode}"
  }
}