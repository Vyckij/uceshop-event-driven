# =====================================================================
# 02-plataforma · security groups
#
# Se crean TODOS ahora (son gratis), aunque los servicios ECS lleguen
# en la fase siguiente: así RDS ya acepta solo a su aplicación.
#
# Regla general: la ENTRADA es estricta (solo quien la necesita);
# la SALIDA de las tareas queda abierta (ECR, CloudWatch, SSM).
# Las descripciones van sin tildes: AWS no las acepta en security groups.
# =====================================================================

locals {
  # Un security group por componente: clave => descripción
  security_groups = merge(
    {
      vpclink    = "Interfaces del VPC Link de API Gateway"
      alb        = "ALB interno de la aplicacion"
      dashboard  = "Tareas ECS del dashboard"
      producer   = "Tareas ECS de producer-service"
      consumer   = "Tareas ECS de consumer-service"
      kafka      = "Tarea ECS de Kafka"
      rabbitmq   = "Tarea ECS de RabbitMQ"
      prometheus = "Tarea ECS de Prometheus y kafka-exporter"
      grafana    = "Tarea ECS de Grafana"
    },
    # rds_producer y rds_consumer (uno por base de datos)
    { for k, db in var.databases : "rds_${k}" => "RDS ${db.db_name}" },
  )

  # Todos pueden salir a internet, menos las bases de datos
  sg_with_egress = [for k in keys(local.security_groups) : k if !startswith(k, "rds_")]

  # Entrada entre componentes: <destino>-from-<origen> => puerto
  sg_ingress_from_sg = merge(
    {
      "alb-from-vpclink"                 = { sg = "alb", from = "vpclink", port = var.service_ports.alb_listener }
      "dashboard-from-alb"               = { sg = "dashboard", from = "alb", port = var.service_ports.dashboard }
      "producer-from-alb"                = { sg = "producer", from = "alb", port = var.service_ports.producer }
      "producer-from-dashboard"          = { sg = "producer", from = "dashboard", port = var.service_ports.producer }
      "producer-from-prometheus"         = { sg = "producer", from = "prometheus", port = var.service_ports.producer }
      "consumer-from-alb"                = { sg = "consumer", from = "alb", port = var.service_ports.consumer }
      "consumer-from-dashboard"          = { sg = "consumer", from = "dashboard", port = var.service_ports.consumer }
      "consumer-from-prometheus"         = { sg = "consumer", from = "prometheus", port = var.service_ports.consumer }
      "kafka-from-producer"              = { sg = "kafka", from = "producer", port = var.service_ports.kafka }
      "kafka-from-consumer"              = { sg = "kafka", from = "consumer", port = var.service_ports.kafka }
      "kafka-from-prometheus"            = { sg = "kafka", from = "prometheus", port = var.service_ports.kafka }
      "rabbitmq-amqp-from-consumer"      = { sg = "rabbitmq", from = "consumer", port = var.service_ports.rabbitmq_amqp }
      "rabbitmq-metrics-from-prometheus" = { sg = "rabbitmq", from = "prometheus", port = var.service_ports.rabbitmq_metrics }
      "prometheus-from-grafana"          = { sg = "prometheus", from = "grafana", port = var.service_ports.prometheus }
      "prometheus-from-dashboard"        = { sg = "prometheus", from = "dashboard", port = var.service_ports.prometheus }
    },
    # Cada base de datos acepta SOLO a su servicio: rds-producer-from-producer, rds-consumer-from-consumer
    {
      for k, db in var.databases :
      "rds-${k}-from-${k}" => { sg = "rds_${k}", from = k, port = var.service_ports.postgres }
    },
  )

  # Consolas abiertas solo a las IP de administración (var.admin_cidrs)
  console_ports = {
    grafana    = var.service_ports.grafana
    prometheus = var.service_ports.prometheus
    rabbitmq   = var.service_ports.rabbitmq_console
  }

  sg_ingress_from_admin = merge([
    for sg, port in local.console_ports : {
      for cidr in var.admin_cidrs :
      "${sg}-from-${cidr}" => { sg = sg, port = port, cidr = cidr }
    }
  ]...)
}

# ---------------------------------------------------------------------
# Security group por defecto de la VPC: sin reglas (buena práctica)
# ---------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-default-sin-reglas"
  }
}

# ---------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------
resource "aws_security_group" "this" {
  for_each = local.security_groups

  name        = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  description = each.value
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  }
}

# ---------------------------------------------------------------------
# Entrada entre componentes (referencia a otro security group)
# ---------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each = local.sg_ingress_from_sg

  security_group_id            = aws_security_group.this[each.value.sg].id
  referenced_security_group_id = aws_security_group.this[each.value.from].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "Desde ${each.value.from} al puerto ${each.value.port}"

  tags = {
    Name = each.key
  }
}

# ---------------------------------------------------------------------
# Entrada a las consolas desde tus IP
# ---------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "from_admin" {
  for_each = local.sg_ingress_from_admin

  security_group_id = aws_security_group.this[each.value.sg].id
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "Consola desde IP de administracion"

  tags = {
    Name = each.key
  }
}

# ---------------------------------------------------------------------
# Salida: abierta para todo menos RDS
# ---------------------------------------------------------------------
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = toset(local.sg_with_egress)

  security_group_id = aws_security_group.this[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Salida a internet y a la VPC"

  tags = {
    Name = "${each.key}-egress"
  }
}
