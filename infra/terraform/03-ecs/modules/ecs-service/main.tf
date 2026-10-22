# =====================================================================
# Módulo ecs-service · log group + task definition + servicio ECS
# =====================================================================

locals {
  family         = "${var.platform.name_prefix}-${var.name}"
  log_group_name = "/ecs/${var.platform.name_prefix}/${var.name}"

  # Definición de cada contenedor en el formato de ECS.
  # Los campos que quedan en null se eliminan antes de convertir a JSON.
  container_definitions = [
    for c in var.containers : {
      for key, value in {
        name         = c.name
        image        = c.image
        essential    = c.essential
        portMappings = [for p in c.ports : { containerPort = p, hostPort = p, protocol = "tcp" }]
        environment  = [for k in sort(keys(c.environment)) : { name = k, value = c.environment[k] }]
        secrets      = [for k in sort(keys(c.secrets)) : { name = k, valueFrom = c.secrets[k] }]
        entryPoint   = c.entry_point
        command      = c.command
        mountPoints  = []
        volumesFrom  = []
        stopTimeout  = c.stop_timeout

        healthCheck = c.health_check == null ? null : {
          command     = c.health_check.command
          interval    = c.health_check.interval
          timeout     = c.health_check.timeout
          retries     = c.health_check.retries
          startPeriod = c.health_check.start_period
        }

        restartPolicy = c.restart ? { enabled = true, restartAttemptPeriod = 60 } : null

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this.name
            "awslogs-region"        = var.platform.aws_region
            "awslogs-stream-prefix" = var.name
          }
        }
      } : key => value if value != null
    }
  ]
}

# ---------------------------------------------------------------------
# Logs en CloudWatch: /ecs/uceshop-academy/<servicio>
# ---------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.platform.log_retention_days

  tags = {
    Service = var.name
  }
}

# ---------------------------------------------------------------------
# Task definition
# ---------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = local.family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.platform.execution_role_arn
  task_role_arn            = var.platform.task_role_arn
  container_definitions    = jsonencode(local.container_definitions)

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.platform.cpu_architecture
  }

  tags = {
    Service = var.name
  }
}

# ---------------------------------------------------------------------
# Servicio ECS
# ---------------------------------------------------------------------
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.platform.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = var.platform.capacity_provider
    weight            = 1
  }

  # Las tareas se reparten entre las subredes públicas de las dos zonas
  network_configuration {
    subnets          = var.platform.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.platform.assign_public_ip
  }

  # ECS registra la IP de cada tarea en estos target groups
  dynamic "load_balancer" {
    for_each = var.load_balancers

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  health_check_grace_period_seconds = length(var.load_balancers) > 0 ? var.health_check_grace_period : null

  # Con datos: primero se apaga la tarea vieja (nunca hay dos Kafka a la vez).
  # Sin datos: la nueva arranca antes de apagar la vieja (sin corte).
  deployment_minimum_healthy_percent = var.single_instance ? 0 : 100
  deployment_maximum_percent         = var.single_instance ? 100 : 200

  # Con 2 o más tareas, ECS las mantiene repartidas entre las dos zonas
  availability_zone_rebalancing = var.single_instance ? "DISABLED" : "ENABLED"

  # Si la nueva versión no arranca, ECS vuelve a la anterior
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command  = var.platform.enable_execute_command
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  wait_for_steady_state   = var.platform.wait_for_steady_state

  tags = {
    Service = var.name
  }
}