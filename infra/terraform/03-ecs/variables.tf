# =====================================================================
# 03-ecs · variables
#
# Esta etapa no lee el estado de 02-plataforma: encuentra la VPC, las
# subredes, los security groups, el clúster, las bases y los parámetros
# SSM por su NOMBRE. project y environment deben ser iguales a los de
# 02-plataforma.
# =====================================================================

# ---------------------------------------------------------------------
# General
# ---------------------------------------------------------------------
variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto (el mismo de 02-plataforma)"
  type        = string
  default     = "uceshop"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project: solo minúsculas, números y guiones; empieza con letra."
  }
}

variable "environment" {
  description = "Nombre del entorno (el mismo de 02-plataforma)"
  type        = string
  default     = "academy"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment: solo minúsculas, números y guiones; empieza con letra."
  }

  # Los target groups admiten nombres de hasta 32 caracteres
  validation {
    condition     = length("${var.project}-${var.environment}") <= 16
    error_message = "project-environment no puede superar 16 caracteres (uceshop-academy tiene 15)."
  }
}

variable "extra_tags" {
  description = "Etiquetas adicionales para todos los recursos"
  type        = map(string)
  default     = {}
}

variable "databases" {
  description = "Bases creadas en 02-plataforma: servicio => nombre de la base. La instancia RDS se llama <project>-<environment>-<nombre>"
  type        = map(string)
  default = {
    producer = "producerdb"
    consumer = "consumerdb"
  }

  validation {
    condition     = length(setsubtract(toset(["producer", "consumer"]), toset(keys(var.databases)))) == 0
    error_message = "databases: deben existir las claves producer y consumer."
  }
}

# ---------------------------------------------------------------------
# Imágenes
# ---------------------------------------------------------------------
variable "ecr_repository_prefix" {
  description = "Prefijo de los repositorios de 01-ecr: <prefijo>/<nombre>"
  type        = string
  default     = "uceshop"
}

variable "image_tags" {
  description = "Etiqueta de cada imagen en ECR"
  type        = map(string)
  default = {
    "kafka"            = "4.3.1"
    "kafka-exporter"   = "v1.10.0"
    "rabbitmq"         = "1.0.0"
    "producer-service" = "1.0.0"
    "consumer-service" = "1.0.0"
    "prometheus"       = "1.0.0"
    "grafana"          = "1.0.0"
    "dashboard"        = "1.0.0"
  }

  validation {
    condition = length(setsubtract(
      toset(["kafka", "kafka-exporter", "rabbitmq", "producer-service", "consumer-service", "prometheus", "grafana", "dashboard"]),
      toset(keys(var.image_tags))
    )) == 0
    error_message = "image_tags: falta la etiqueta de alguna de las 8 imágenes."
  }
}

variable "image_overrides" {
  description = "Imagen completa que reemplaza a la de ECR. Ejemplo: { kafka = \"apache/kafka:4.3.1\" }. Vacío = todas desde ECR"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------
# Tareas
# La clave es el nombre del servicio ECS.
# health_check_grace_period: segundos que ECS espera antes de mirar la
# salud en el balanceador (Spring Boot con 0.25 vCPU tarda en arrancar).
# ---------------------------------------------------------------------
variable "services" {
  description = "CPU (256 = 0.25 vCPU), memoria (MB), número de tareas y gracia de arranque de cada servicio"
  type = map(object({
    cpu                       = number
    memory                    = number
    desired_count             = number
    health_check_grace_period = number
  }))
  default = {
    "kafka"            = { cpu = 512, memory = 2048, desired_count = 1, health_check_grace_period = 120 }
    "rabbitmq"         = { cpu = 256, memory = 1024, desired_count = 1, health_check_grace_period = 120 }
    "producer-service" = { cpu = 256, memory = 1024, desired_count = 1, health_check_grace_period = 300 }
    "consumer-service" = { cpu = 256, memory = 1024, desired_count = 1, health_check_grace_period = 300 }
    "prometheus"       = { cpu = 256, memory = 1024, desired_count = 1, health_check_grace_period = 60 }
    "grafana"          = { cpu = 256, memory = 512, desired_count = 1, health_check_grace_period = 120 }
    "dashboard"        = { cpu = 256, memory = 512, desired_count = 1, health_check_grace_period = 60 }
  }

  validation {
    condition = length(setsubtract(
      toset(["kafka", "rabbitmq", "producer-service", "consumer-service", "prometheus", "grafana", "dashboard"]),
      toset(keys(var.services))
    )) == 0
    error_message = "services: deben existir los 7 servicios."
  }

  validation {
    condition     = alltrue([for k in ["kafka", "rabbitmq", "prometheus", "grafana"] : try(var.services[k].desired_count, 0) <= 1])
    error_message = "services: kafka, rabbitmq, prometheus y grafana guardan datos dentro de la tarea; usa 0 o 1 tarea."
  }
}

variable "paused" {
  description = "true = todas las tareas en 0 (ahorra Fargate e IP públicas; balanceadores y RDS siguen cobrando)"
  type        = bool
  default     = false
}

variable "capacity_provider" {
  description = "FARGATE (estable) o FARGATE_SPOT (más barato, AWS puede interrumpir la tarea)"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.capacity_provider)
    error_message = "capacity_provider: FARGATE o FARGATE_SPOT."
  }
}

variable "cpu_architecture" {
  description = "Arquitectura de las imágenes: X86_64 (amd64) o ARM64"
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture: X86_64 o ARM64."
  }
}

variable "assign_public_ip" {
  description = "IP pública por tarea. Sin NAT Gateway es obligatoria para descargar las imágenes"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------
# Puertos
# dashboard_nlb: el NLB no puede repetir puertos, y el dashboard y el
# producer usan ambos el 8080 en su contenedor.
# ---------------------------------------------------------------------
variable "ports" {
  description = "Puertos de los contenedores y del NLB interno"
  type = object({
    dashboard          = number
    dashboard_nlb      = number
    producer           = number
    consumer           = number
    kafka              = number
    kafka_broker_local = number
    kafka_controller   = number
    kafka_exporter     = number
    rabbitmq_amqp      = number
    rabbitmq_console   = number
    rabbitmq_metrics   = number
    prometheus         = number
    grafana            = number
  })
  default = {
    dashboard          = 8080
    dashboard_nlb      = 8088
    producer           = 8080
    consumer           = 8081
    kafka              = 9092
    kafka_broker_local = 19092
    kafka_controller   = 9093
    kafka_exporter     = 9308
    rabbitmq_amqp      = 5672
    rabbitmq_console   = 15672
    rabbitmq_metrics   = 15692
    prometheus         = 9090
    grafana            = 3000
  }
}

# ---------------------------------------------------------------------
# NLB interno (descubrimiento de servicios)
# ---------------------------------------------------------------------
variable "nlb_tcp_idle_timeout_seconds" {
  description = "Segundos que el NLB mantiene una conexión sin tráfico (Kafka y AMQP usan conexiones largas)"
  type        = number
  default     = 3600

  validation {
    condition     = var.nlb_tcp_idle_timeout_seconds >= 60 && var.nlb_tcp_idle_timeout_seconds <= 6000
    error_message = "nlb_tcp_idle_timeout_seconds: entre 60 y 6000."
  }
}

variable "deregistration_delay_seconds" {
  description = "Segundos que el balanceador espera antes de quitar una tarea que se detiene"
  type        = number
  default     = 15
}

# ---------------------------------------------------------------------
# Configuración de las aplicaciones
# ---------------------------------------------------------------------
variable "kafka_cluster_id" {
  description = "Identificador del clúster KRaft (22 caracteres base64)"
  type        = string
  default     = "4L6g3nShT-eMCtK--X86sw"
}

variable "kafka_heap_opts" {
  description = "Memoria de la JVM de Kafka"
  type        = string
  default     = "-Xms512m -Xmx512m"
}

variable "kafka_topic_orders" {
  description = "Tópico de pedidos"
  type        = string
  default     = "orders"
}

variable "kafka_group_id" {
  description = "Grupo de consumidores del consumer-service"
  type        = string
  default     = "consumer-service-group"
}

variable "kafka_exporter_protocol_version" {
  description = "Versión de protocolo que usa kafka-exporter (compatible con Kafka 4.x)"
  type        = string
  default     = "3.9.0"
}

variable "rabbitmq_user" {
  description = "Usuario de RabbitMQ (la contraseña viene de SSM)"
  type        = string
  default     = "uceshop"
}

variable "grafana_admin_user" {
  description = "Usuario administrador de Grafana (la contraseña viene de SSM)"
  type        = string
  default     = "admin"
}

variable "prometheus_retention" {
  description = "Tiempo que Prometheus guarda las métricas (el disco de Fargate es temporal)"
  type        = string
  default     = "3d"
}

variable "db_sslmode" {
  description = "Modo SSL de JDBC. RDS PostgreSQL 15+ exige SSL (rds.force_ssl = 1)"
  type        = string
  default     = "require"

  validation {
    condition     = contains(["require", "verify-ca", "verify-full", "prefer"], var.db_sslmode)
    error_message = "db_sslmode: require, verify-ca, verify-full o prefer."
  }
}

variable "java_tool_options" {
  description = "Opciones de la JVM de producer y consumer"
  type        = string
  default     = "-XX:MaxRAMPercentage=75.0 -Dsun.net.inetaddr.ttl=30"
}

# ---------------------------------------------------------------------
# Permisos (IAM)
# ---------------------------------------------------------------------
variable "create_iam_roles" {
  description = "false = usar LabRole (AWS Academy no permite crear roles). true = crear roles propios (cuenta normal)"
  type        = bool
  default     = false
}

variable "lab_role_name" {
  description = "Rol existente que se usa cuando create_iam_roles = false"
  type        = string
  default     = "LabRole"
}

# ---------------------------------------------------------------------
# Operación
# ---------------------------------------------------------------------
variable "log_retention_days" {
  description = "Días que se guardan los logs en CloudWatch"
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "log_retention_days: 1, 3, 5, 7, 14 o 30."
  }
}

variable "enable_execute_command" {
  description = "Permite entrar a un contenedor con 'aws ecs execute-command'"
  type        = bool
  default     = true
}

variable "wait_for_steady_state" {
  description = "Terraform espera a que cada servicio esté sano antes de terminar"
  type        = bool
  default     = true
}