# =====================================================================
# 02-plataforma · Cloud Map y clúster ECS
#
# Solo el clúster: los servicios y las task definitions llegan en la
# fase siguiente.
# =====================================================================

# DNS privado de la VPC: kafka.uceshop.local, producer-service.uceshop.local...


resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = var.ecs_container_insights
  }

  tags = {
    Name = local.name_prefix
  }
}

# Fargate normal y Fargate Spot disponibles; por defecto se usa el elegido
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = var.ecs_default_capacity_provider
    weight            = 1
    base              = 0
  }
}
