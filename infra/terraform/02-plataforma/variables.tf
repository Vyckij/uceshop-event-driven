# =====================================================================
# 02-plataforma · variables
#
# Todo lo que cambia entre cuentas, regiones o laboratorios está aquí.
# Los valores por defecto corresponden a AWS Academy en us-east-1.
# Para otro entorno, copia terraform.tfvars.example como terraform.tfvars
# y cambia solo lo necesario.
# =====================================================================

# ---------------------------------------------------------------------
# General
# ---------------------------------------------------------------------
variable "aws_region" {
  description = "Región de AWS donde se crea todo"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto; prefijo de nombres y etiquetas"
  type        = string
  default     = "uceshop"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project: solo minúsculas, números y guiones; empieza con letra; máximo 21 caracteres."
  }
}

variable "environment" {
  description = "Nombre del entorno (academy, dev, prod...). Permite tener varios entornos en una misma cuenta"
  type        = string
  default     = "academy"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment: solo minúsculas, números y guiones; empieza con letra; máximo 16 caracteres."
  }
}

variable "extra_tags" {
  description = "Etiquetas adicionales para todos los recursos (por ejemplo, Owner o Course)"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------
variable "availability_zones" {
  description = "Zonas de disponibilidad. Mínimo 2 para alta disponibilidad (ALB y RDS lo exigen)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "availability_zones: se necesitan al menos 2 zonas."
  }

  validation {
    condition     = alltrue([for az in var.availability_zones : startswith(az, var.aws_region)])
    error_message = "availability_zones: todas las zonas deben pertenecer a aws_region (por ejemplo us-east-1a para us-east-1)."
  }

  validation {
    condition     = length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "availability_zones: no repitas zonas."
  }
}

variable "vpc_cidr" {
  description = "Rango de direcciones de la VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr: debe ser un CIDR válido, por ejemplo 10.0.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "Una subred pública por zona, en el mismo orden que availability_zones"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "public_subnet_cidrs: debe haber un CIDR por cada zona de availability_zones."
  }

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "public_subnet_cidrs: todos deben ser CIDR válidos."
  }
}

variable "data_subnet_cidrs" {
  description = "Una subred privada de datos por zona, en el mismo orden que availability_zones"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]

  validation {
    condition     = length(var.data_subnet_cidrs) == length(var.availability_zones)
    error_message = "data_subnet_cidrs: debe haber un CIDR por cada zona de availability_zones."
  }

  validation {
    condition     = alltrue([for c in var.data_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "data_subnet_cidrs: todos deben ser CIDR válidos."
  }
}

variable "admin_cidrs" {
  description = "IP públicas (con /32) que pueden abrir Grafana, Prometheus y la consola de RabbitMQ. Vacío = consolas cerradas"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0))])
    error_message = "admin_cidrs: cada valor debe ser un CIDR válido, por ejemplo 190.10.20.30/32."
  }

  validation {
    condition     = length(distinct(var.admin_cidrs)) == length(var.admin_cidrs)
    error_message = "admin_cidrs: no repitas IP."
  }
}

variable "service_ports" {
  description = "Puertos de cada componente (deben coincidir con las imágenes en ECR)"
  type = object({
    alb_listener     = number
    dashboard        = number
    producer         = number
    consumer         = number
    kafka            = number
    rabbitmq_amqp    = number
    rabbitmq_console = number
    rabbitmq_metrics = number
    prometheus       = number
    grafana          = number
    postgres         = number
  })
  default = {
    alb_listener     = 80
    dashboard        = 8080
    producer         = 8080
    consumer         = 8081
    kafka            = 9092
    rabbitmq_amqp    = 5672
    rabbitmq_console = 15672
    rabbitmq_metrics = 15692
    prometheus       = 9090
    grafana          = 3000
    postgres         = 5432
  }
}

variable "service_namespace" {
  description = "Espacio de nombres DNS interno (Cloud Map). Las imágenes de Prometheus y Grafana usan uceshop.local"
  type        = string
  default     = "uceshop.local"
}

# ---------------------------------------------------------------------
# Bases de datos (RDS PostgreSQL)
# ---------------------------------------------------------------------
variable "databases" {
  description = "Una instancia RDS por servicio. La clave (producer, consumer) es también el nombre del security group de la aplicación"
  type = map(object({
    db_name  = string
    username = string
    az_index = number # zona preferida mientras sea Single-AZ (0 = primera zona)
  }))
  default = {
    producer = { db_name = "producerdb", username = "producer_user", az_index = 0 }
    consumer = { db_name = "consumerdb", username = "consumer_user", az_index = 1 }
  }

  validation {
    condition     = alltrue([for k in keys(var.databases) : contains(["producer", "consumer"], k)])
    error_message = "databases: las claves deben ser producer y/o consumer."
  }
}

variable "db_engine_version" {
  description = "Versión de PostgreSQL: mayor (18) o completa (18.x). Recomendado: la completa, consultada antes del primer apply"
  type        = string
  default     = "18"
}

variable "db_instance_class" {
  description = "Tamaño de las instancias RDS (Learner Lab admite tamaños nano, micro, small y medium)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Disco inicial de cada base, en GB (mínimo 20; Learner Lab admite hasta 100)"
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage: mínimo 20 GB."
  }
}

variable "db_max_allocated_storage" {
  description = "Crecimiento automático del disco hasta este tamaño en GB. 0 = desactivado"
  type        = number
  default     = 0
}

variable "db_storage_type" {
  description = "Tipo de disco de RDS. Learner Lab solo admite gp2; en una cuenta normal puede ser gp3"
  type        = string
  default     = "gp2"

  validation {
    condition     = contains(["gp2", "gp3"], var.db_storage_type)
    error_message = "db_storage_type: gp2 o gp3."
  }
}

variable "db_storage_encrypted" {
  description = "Cifrar el disco de RDS con la clave administrada por AWS"
  type        = bool
  default     = true
}

variable "db_multi_az" {
  description = "true = réplica en espera en otra zona (alta disponibilidad de la base; duplica el costo de RDS). Learner Lab NO lo admite: false allí"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Días de copias automáticas (0 = sin copias)"
  type        = number
  default     = 1
}

variable "db_backup_window" {
  description = "Ventana diaria de copias, en UTC"
  type        = string
  default     = "07:00-07:30"
}

variable "db_maintenance_window" {
  description = "Ventana semanal de mantenimiento, en UTC"
  type        = string
  default     = "sat:08:00-sat:08:30"
}

variable "db_auto_minor_version_upgrade" {
  description = "Permitir que AWS actualice versiones menores automáticamente (false evita reinicios inesperados durante la exhibición)"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Impide borrar las bases con terraform destroy. true en producción"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "No tomar una copia final al destruir. false en producción"
  type        = bool
  default     = true
}

variable "password_length" {
  description = "Longitud de las contraseñas generadas"
  type        = number
  default     = 24

  validation {
    condition     = var.password_length >= 16 && var.password_length <= 64
    error_message = "password_length: entre 16 y 64."
  }
}

# ---------------------------------------------------------------------
# ECS
# ---------------------------------------------------------------------
variable "ecs_container_insights" {
  description = "Métricas avanzadas de ECS en CloudWatch: disabled, enabled o enhanced (las dos últimas cuestan)"
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["disabled", "enabled", "enhanced"], var.ecs_container_insights)
    error_message = "ecs_container_insights: disabled, enabled o enhanced."
  }
}

variable "ecs_default_capacity_provider" {
  description = "Dónde corren las tareas por defecto: FARGATE (estable) o FARGATE_SPOT (hasta 70 % más barato, puede interrumpirse)"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.ecs_default_capacity_provider)
    error_message = "ecs_default_capacity_provider: FARGATE o FARGATE_SPOT."
  }
}
