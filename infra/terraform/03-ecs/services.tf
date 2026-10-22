# =====================================================================
# 03-ecs · servicios ECS Fargate
#
# Todos los servicios se encuentran entre sí a través del NLB interno
# (local.endpoint), nunca por la IP de la tarea.
#
# Orden: kafka y rabbitmq primero; producer y consumer cuando Kafka y
# RabbitMQ están sanos; prometheus, grafana y dashboard en paralelo.
# =====================================================================

locals {
  # Datos comunes que recibe cada servicio
  platform = {
    name_prefix            = local.name_prefix
    aws_region             = var.aws_region
    cluster_arn            = data.aws_ecs_cluster.this.arn
    subnet_ids             = local.public_subnet_ids
    assign_public_ip       = var.assign_public_ip
    execution_role_arn     = local.execution_role_arn
    task_role_arn          = local.task_role_arn
    capacity_provider      = var.capacity_provider
    cpu_architecture       = var.cpu_architecture
    enable_execute_command = var.enable_execute_command
    wait_for_steady_state  = var.wait_for_steady_state
    log_retention_days     = var.log_retention_days
  }

  # Target groups del NLB de cada servicio
  service_load_balancers = {
    for svc in keys(var.services) : svc => [
      for k, e in local.nlb_endpoints : {
        target_group_arn = aws_lb_target_group.nlb[k].arn
        container_name   = e.container
        container_port   = e.port
      } if e.service == svc
    ]
  }

  # ---------------------------------------------------------------------
  # Prometheus: la imagen trae una configuración pensada para Cloud Map.
  # Al arrancar, la tarea escribe esta otra (variable PROMETHEUS_CONFIG).
  # Los nombres de los jobs son los mismos que en local, así el
  # dashboard de Grafana funciona sin cambios.
  # ---------------------------------------------------------------------
  prometheus_config = yamlencode({
    global = {
      scrape_interval     = "15s"
      scrape_timeout      = "10s"
      evaluation_interval = "15s"
      external_labels = {
        project     = var.project
        environment = "aws"
      }
    }
    scrape_configs = [
      {
        job_name       = "prometheus"
        static_configs = [{ targets = ["localhost:${var.ports.prometheus}"] }]
      },
      {
        job_name       = "producer-service"
        metrics_path   = "/actuator/prometheus"
        static_configs = [{ targets = [local.endpoint["producer"]] }]
      },
      {
        job_name       = "consumer-service"
        metrics_path   = "/actuator/prometheus"
        static_configs = [{ targets = [local.endpoint["consumer"]] }]
      },
      {
        # kafka-exporter corre en la MISMA tarea que Prometheus
        job_name       = "kafka"
        static_configs = [{ targets = ["localhost:${var.ports.kafka_exporter}"] }]
      },
      {
        job_name       = "rabbitmq"
        metrics_path   = "/metrics/per-object"
        static_configs = [{ targets = [local.endpoint["rmq-metrics"]] }]
      },
    ]
  })

  # ---------------------------------------------------------------------
  # Grafana: fuente de datos que apunta a Prometheus por el NLB
  # ---------------------------------------------------------------------
  grafana_datasources = yamlencode({
    apiVersion = 1
    datasources = [{
      name      = "Prometheus"
      uid       = "prometheus" # el dashboard de Grafana usa este uid
      type      = "prometheus"
      access    = "proxy"
      url       = "http://${local.endpoint["prometheus"]}"
      isDefault = true
      editable  = false
      jsonData  = { timeInterval = "15s" }
    }]
  })
}

# ---------------------------------------------------------------------
# 1a. KAFKA (un nodo KRaft: broker + controller)
#   INTERNAL   :9092  -> producer, consumer y kafka-exporter, por el NLB
#   BROKER     :19092 -> solo dentro de la tarea (comunicación interna)
#   CONTROLLER :9093  -> solo dentro de la tarea
# ---------------------------------------------------------------------
module "kafka" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "kafka"
  cpu                       = var.services["kafka"].cpu
  memory                    = var.services["kafka"].memory
  desired_count             = local.desired_count["kafka"]
  health_check_grace_period = var.services["kafka"].health_check_grace_period
  single_instance           = true
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["kafka"]].id]
  load_balancers            = local.service_load_balancers["kafka"]

  containers = [{
    name  = "kafka"
    image = local.images["kafka"]
    ports = [var.ports.kafka]

    environment = {
      KAFKA_NODE_ID       = "1"
      KAFKA_PROCESS_ROLES = "broker,controller"
      CLUSTER_ID          = var.kafka_cluster_id
      KAFKA_LISTENERS     = "INTERNAL://:${var.ports.kafka},BROKER://127.0.0.1:${var.ports.kafka_broker_local},CONTROLLER://127.0.0.1:${var.ports.kafka_controller}"
      # Los clientes reciben la dirección del NLB, que no cambia
      KAFKA_ADVERTISED_LISTENERS                     = "INTERNAL://${local.endpoint["kafka"]},BROKER://127.0.0.1:${var.ports.kafka_broker_local}"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP           = "INTERNAL:PLAINTEXT,BROKER:PLAINTEXT,CONTROLLER:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME               = "BROKER"
      KAFKA_CONTROLLER_LISTENER_NAMES                = "CONTROLLER"
      KAFKA_CONTROLLER_QUORUM_VOTERS                 = "1@127.0.0.1:${var.ports.kafka_controller}"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR         = "1"
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR = "1"
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR            = "1"
      KAFKA_NUM_PARTITIONS                           = "3"
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS         = "0"
      KAFKA_LOG_DIRS                                 = "/var/lib/kafka/data"
      KAFKA_HEAP_OPTS                                = var.kafka_heap_opts
    }

    # Comprobación liviana: ¿el puerto 9092 acepta conexiones?
    health_check = {
      command      = ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/${var.ports.kafka}' || exit 1"]
      interval     = 30
      timeout      = 10
      retries      = 5
      start_period = 90
    }
    stop_timeout = 60
  }]

  depends_on = [aws_lb_listener.nlb, aws_vpc_security_group_ingress_rule.task_from_nlb]
}

# ---------------------------------------------------------------------
# 1b. RABBITMQ (notificaciones y DLQ)
# ---------------------------------------------------------------------
module "rabbitmq" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "rabbitmq"
  cpu                       = var.services["rabbitmq"].cpu
  memory                    = var.services["rabbitmq"].memory
  desired_count             = local.desired_count["rabbitmq"]
  health_check_grace_period = var.services["rabbitmq"].health_check_grace_period
  single_instance           = true
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["rabbitmq"]].id]
  load_balancers            = local.service_load_balancers["rabbitmq"]

  containers = [{
    name  = "rabbitmq"
    image = local.images["rabbitmq"]
    ports = [var.ports.rabbitmq_amqp, var.ports.rabbitmq_console, var.ports.rabbitmq_metrics]

    environment = {
  RABBITMQ_DEFAULT_USER = var.rabbitmq_user
  RABBITMQ_NODENAME     = "rabbit@localhost"
  RABBITMQ_USE_LONGNAME = "false"
}

secrets = {
  RABBITMQ_DEFAULT_PASS = local.secret_arn["rabbitmq-password"]
}

health_check = {
  command      = ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/15692' || exit 1"]
  interval     = 30
  timeout      = 10
  retries      = 5
  start_period = 120
}
    stop_timeout = 60
  }]

  depends_on = [aws_lb_listener.nlb, aws_vpc_security_group_ingress_rule.task_from_nlb]
}

# ---------------------------------------------------------------------
# 2a. PRODUCER-SERVICE (POST /orders -> Kafka, producerdb)
# ---------------------------------------------------------------------
module "producer" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "producer-service"
  cpu                       = var.services["producer-service"].cpu
  memory                    = var.services["producer-service"].memory
  desired_count             = local.desired_count["producer-service"]
  health_check_grace_period = var.services["producer-service"].health_check_grace_period
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["producer-service"]].id]
  load_balancers            = local.service_load_balancers["producer-service"]

  containers = [{
    name  = "producer-service"
    image = local.images["producer-service"]
    ports = [var.ports.producer]

    environment = {
      SERVER_PORT = tostring(var.ports.producer)
      # Reemplaza la URL de application.yml para agregar ?sslmode=require
      SPRING_DATASOURCE_URL   = local.jdbc_url["producer"]
      DB_USER                 = data.aws_db_instance.this["producer"].master_username
      KAFKA_BOOTSTRAP_SERVERS = local.endpoint["kafka"]
      KAFKA_TOPIC_ORDERS      = var.kafka_topic_orders
      JAVA_TOOL_OPTIONS       = var.java_tool_options
    }

    secrets = {
      DB_PASSWORD = local.secret_arn["producer-db-password"]
    }

    health_check = {
      command      = ["CMD-SHELL", "wget -qO- http://localhost:${var.ports.producer}/actuator/health/liveness > /dev/null || exit 1"]
      interval     = 30
      timeout      = 5
      retries      = 5
      start_period = 180
    }
    stop_timeout = 40
  }]

  depends_on = [module.kafka]
}

# ---------------------------------------------------------------------
# 2b. CONSUMER-SERVICE (Kafka -> consumerdb, RabbitMQ)
# ---------------------------------------------------------------------
module "consumer" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "consumer-service"
  cpu                       = var.services["consumer-service"].cpu
  memory                    = var.services["consumer-service"].memory
  desired_count             = local.desired_count["consumer-service"]
  health_check_grace_period = var.services["consumer-service"].health_check_grace_period
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["consumer-service"]].id]
  load_balancers            = local.service_load_balancers["consumer-service"]

  containers = [{
    name  = "consumer-service"
    image = local.images["consumer-service"]
    ports = [var.ports.consumer]

    environment = {
      SERVER_PORT             = tostring(var.ports.consumer)
      SPRING_DATASOURCE_URL   = local.jdbc_url["consumer"]
      DB_USER                 = data.aws_db_instance.this["consumer"].master_username
      KAFKA_BOOTSTRAP_SERVERS = local.endpoint["kafka"]
      KAFKA_TOPIC_ORDERS      = var.kafka_topic_orders
      KAFKA_GROUP_ID          = var.kafka_group_id
      RABBITMQ_HOST           = local.nlb_dns
      RABBITMQ_PORT           = tostring(local.nlb_endpoints["amqp"].listener_port)
      RABBITMQ_USER           = var.rabbitmq_user
      JAVA_TOOL_OPTIONS       = var.java_tool_options
    }

    secrets = {
      DB_PASSWORD       = local.secret_arn["consumer-db-password"]
      RABBITMQ_PASSWORD = local.secret_arn["rabbitmq-password"]
    }

    health_check = {
      command      = ["CMD-SHELL", "wget -qO- http://localhost:${var.ports.consumer}/actuator/health/liveness > /dev/null || exit 1"]
      interval     = 30
      timeout      = 5
      retries      = 5
      start_period = 180
    }
    stop_timeout = 40
  }]

  depends_on = [module.kafka, module.rabbitmq]
}

# ---------------------------------------------------------------------
# 3. PROMETHEUS + KAFKA-EXPORTER (dos contenedores en la misma tarea)
# ---------------------------------------------------------------------
module "prometheus" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "prometheus"
  cpu                       = var.services["prometheus"].cpu
  memory                    = var.services["prometheus"].memory
  desired_count             = local.desired_count["prometheus"]
  health_check_grace_period = var.services["prometheus"].health_check_grace_period
  single_instance           = true
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["prometheus"]].id]
  load_balancers            = local.service_load_balancers["prometheus"]

  containers = [
    {
      name  = "prometheus"
      image = local.images["prometheus"]
      ports = [var.ports.prometheus]

      environment = {
        PROMETHEUS_CONFIG = local.prometheus_config
      }

      # Escribe la configuración de AWS y arranca Prometheus
      entry_point = ["/bin/sh", "-c"]
      command = [
        "printf '%s' \"$PROMETHEUS_CONFIG\" > /prometheus/prometheus.yml && exec /bin/prometheus --config.file=/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=${var.prometheus_retention}",
      ]

      health_check = {
        command      = ["CMD-SHELL", "wget -q --spider http://localhost:${var.ports.prometheus}/-/healthy || exit 1"]
        interval     = 30
        timeout      = 5
        retries      = 3
        start_period = 30
      }
    },
    {
      name      = "kafka-exporter"
      image     = local.images["kafka-exporter"]
      essential = false # si se cae, Prometheus sigue funcionando
      restart   = true  # y ECS lo vuelve a arrancar
      ports     = [var.ports.kafka_exporter]
      command = [
        "--kafka.server=${local.endpoint["kafka"]}",
        "--kafka.version=${var.kafka_exporter_protocol_version}",
      ]

      health_check = {
        command      = ["CMD-SHELL", "wget -q --spider http://localhost:${var.ports.kafka_exporter}/metrics || exit 1"]
        interval     = 30
        timeout      = 5
        retries      = 3
        start_period = 30
      }
    },
  ]

  depends_on = [aws_lb_listener.nlb, aws_vpc_security_group_ingress_rule.task_from_nlb]
}

# ---------------------------------------------------------------------
# 4a. GRAFANA
# ---------------------------------------------------------------------
module "grafana" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "grafana"
  cpu                       = var.services["grafana"].cpu
  memory                    = var.services["grafana"].memory
  desired_count             = local.desired_count["grafana"]
  health_check_grace_period = var.services["grafana"].health_check_grace_period
  single_instance           = true
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["grafana"]].id]
  load_balancers            = local.service_load_balancers["grafana"]

  containers = [{
    name  = "grafana"
    image = local.images["grafana"]
    ports = [var.ports.grafana]

    environment = {
      GF_SECURITY_ADMIN_USER = var.grafana_admin_user
      # Grafana lee la configuración automática desde /tmp/provisioning
      GF_PATHS_PROVISIONING = "/tmp/provisioning"
      GRAFANA_DATASOURCES   = local.grafana_datasources
    }

    secrets = {
      GF_SECURITY_ADMIN_PASSWORD = local.secret_arn["grafana-admin-password"]
    }

    # Copia el proveedor de dashboards de la imagen, escribe la fuente de
    # datos que apunta al NLB y arranca Grafana
    entry_point = ["/bin/sh", "-c"]
    command = [
      "mkdir -p /tmp/provisioning/datasources /tmp/provisioning/dashboards /tmp/provisioning/alerting /tmp/provisioning/plugins /tmp/provisioning/notifiers && cp /etc/grafana/provisioning/dashboards/*.yml /tmp/provisioning/dashboards/ && printf '%s' \"$GRAFANA_DATASOURCES\" > /tmp/provisioning/datasources/datasource.yml && exec /run.sh",
    ]

    health_check = {
      command      = ["CMD-SHELL", "wget -q --spider http://localhost:${var.ports.grafana}/api/health || exit 1"]
      interval     = 30
      timeout      = 5
      retries      = 3
      start_period = 60
    }
  }]

  depends_on = [aws_lb_listener.nlb, aws_vpc_security_group_ingress_rule.task_from_nlb]
}

# ---------------------------------------------------------------------
# 4b. DASHBOARD (Nginx: página web + proxy /api hacia los servicios)
# ---------------------------------------------------------------------
module "dashboard" {
  source = "./modules/ecs-service"

  platform                  = local.platform
  name                      = "dashboard"
  cpu                       = var.services["dashboard"].cpu
  memory                    = var.services["dashboard"].memory
  desired_count             = local.desired_count["dashboard"]
  health_check_grace_period = var.services["dashboard"].health_check_grace_period
  security_group_ids        = [data.aws_security_group.this[local.service_security_group["dashboard"]].id]
  load_balancers            = local.service_load_balancers["dashboard"]

  containers = [{
    name  = "dashboard"
    image = local.images["dashboard"]
    ports = [var.ports.dashboard]

    environment = {
      PRODUCER_UPSTREAM   = local.endpoint["producer"]
      CONSUMER_UPSTREAM   = local.endpoint["consumer"]
      PROMETHEUS_UPSTREAM = local.endpoint["prometheus"]
      # DNS de la VPC: Nginx resuelve el nombre del NLB
      NGINX_RESOLVER = local.vpc_dns_resolver
    }

    health_check = {
      command      = ["CMD-SHELL", "wget -q --spider http://localhost:${var.ports.dashboard}/health || exit 1"]
      interval     = 30
      timeout      = 5
      retries      = 3
      start_period = 20
    }
  }]

  depends_on = [aws_lb_listener.nlb, aws_vpc_security_group_ingress_rule.task_from_nlb]
}