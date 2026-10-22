# =====================================================================
# 03-ecs · NLB interno = descubrimiento de servicios sin Cloud Map
#
# AWS Academy bloquea Cloud Map. En su lugar, un Network Load Balancer
# INTERNO (sin IP pública) da a cada servicio una dirección fija:
#
#   <dns-del-nlb>:9092   -> kafka            <dns-del-nlb>:8080 -> producer-service
#   <dns-del-nlb>:5672   -> rabbitmq (AMQP)  <dns-del-nlb>:8081 -> consumer-service
#   <dns-del-nlb>:15692  -> rabbitmq métricas <dns-del-nlb>:9090 -> prometheus
#   <dns-del-nlb>:15672  -> rabbitmq consola  <dns-del-nlb>:3000 -> grafana
#   <dns-del-nlb>:8088   -> dashboard
#
# ECS registra solo la IP de cada tarea en su target group: si una tarea
# se reinicia y cambia de IP, la dirección del NLB sigue siendo la misma.
# El ALB público de 04-exposicion entra por este mismo NLB.
# =====================================================================

locals {
  nlb_endpoints = {
    "kafka" = {
      service         = "kafka"
      container       = "kafka"
      port            = var.ports.kafka
      listener_port   = var.ports.kafka
      health_protocol = "TCP"
      health_port     = "traffic-port"
      health_path     = null
    }
    "amqp" = {
      service         = "rabbitmq"
      container       = "rabbitmq"
      port            = var.ports.rabbitmq_amqp
      listener_port   = var.ports.rabbitmq_amqp
      health_protocol = "TCP"
      # Se revisa el puerto de métricas para no llenar el log de RabbitMQ
      # con conexiones AMQP abiertas y cerradas cada 15 segundos
      health_port = tostring(var.ports.rabbitmq_metrics)
      health_path = null
    }
    "rmq-metrics" = {
      service         = "rabbitmq"
      container       = "rabbitmq"
      port            = var.ports.rabbitmq_metrics
      listener_port   = var.ports.rabbitmq_metrics
      health_protocol = "TCP"
      health_port     = "traffic-port"
      health_path     = null
    }
    "rmq-console" = {
      service         = "rabbitmq"
      container       = "rabbitmq"
      port            = var.ports.rabbitmq_console
      listener_port   = var.ports.rabbitmq_console
      health_protocol = "HTTP"
      health_port     = "traffic-port"
      health_path     = "/"
    }
    "producer" = {
      service         = "producer-service"
      container       = "producer-service"
      port            = var.ports.producer
      listener_port   = var.ports.producer
      health_protocol = "HTTP"
      health_port     = "traffic-port"
      health_path     = "/actuator/health/liveness"
    }
    "consumer" = {
      service         = "consumer-service"
      container       = "consumer-service"
      port            = var.ports.consumer
      listener_port   = var.ports.consumer
      health_protocol = "HTTP"
      health_port     = "traffic-port"
      health_path     = "/actuator/health/liveness"
    }
    "prometheus" = {
      service         = "prometheus"
      container       = "prometheus"
      port            = var.ports.prometheus
      listener_port   = var.ports.prometheus
      health_protocol = "HTTP"
      health_port     = "traffic-port"
      health_path     = "/-/healthy"
    }
    "grafana" = {
      service         = "grafana"
      container       = "grafana"
      port            = var.ports.grafana
      listener_port   = var.ports.grafana
      health_protocol = "HTTP"
      health_port     = "traffic-port"
      health_path     = "/api/health"
    }
    "dashboard" = {
      service         = "dashboard"
      container       = "dashboard"
      port            = var.ports.dashboard
      listener_port   = var.ports.dashboard_nlb
      health_protocol = "HTTP"
      health_port     = "traffic-port"
      health_path     = "/health"
    }
  }

  nlb_dns = aws_lb.internal.dns_name

  # Dirección interna de cada servicio
  endpoint = { for k, e in local.nlb_endpoints : k => "${local.nlb_dns}:${e.listener_port}" }
}

resource "aws_lb" "internal" {
  name               = "${local.name_prefix}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = local.public_subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  # Obligatorio con una sola tarea por servicio: cualquier nodo del NLB
  # (zona a o b) debe poder llegar a la tarea, esté en la zona que esté
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

  tags = {
    Name = "${local.name_prefix}-nlb"
  }
}

resource "aws_lb_target_group" "nlb" {
  for_each = local.nlb_endpoints

  name                 = "${local.name_prefix}-n-${each.key}"
  port                 = each.value.port
  protocol             = "TCP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.this.id
  deregistration_delay = var.deregistration_delay_seconds

  # La tarea ve como origen la IP del NLB (así funcionan los security groups
  # y una tarea puede llamarse a sí misma a través del NLB)
  preserve_client_ip = "false"

  health_check {
    enabled             = true
    protocol            = each.value.health_protocol
    port                = each.value.health_port
    path                = each.value.health_path
    matcher             = each.value.health_protocol == "HTTP" ? "200-399" : null
    interval            = 15
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${local.name_prefix}-n-${each.key}"
    Service = each.value.service
  }
}

resource "aws_lb_listener" "nlb" {
  for_each = local.nlb_endpoints

  load_balancer_arn        = aws_lb.internal.arn
  port                     = each.value.listener_port
  protocol                 = "TCP"
  tcp_idle_timeout_seconds = var.nlb_tcp_idle_timeout_seconds

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[each.key].arn
  }

  tags = {
    Name = "${local.name_prefix}-nlb-${each.key}"
  }
}