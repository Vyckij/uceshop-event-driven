# =====================================================================
# Módulo ecs-service · variables
# Un servicio ECS Fargate = log group + task definition + servicio
# =====================================================================

variable "platform" {
  description = "Datos comunes a todos los servicios (clúster, red, roles, opciones)"
  type = object({
    name_prefix            = string
    aws_region             = string
    cluster_arn            = string
    subnet_ids             = list(string)
    assign_public_ip       = bool
    execution_role_arn     = string
    task_role_arn          = string
    capacity_provider      = string
    cpu_architecture       = string
    enable_execute_command = bool
    wait_for_steady_state  = bool
    log_retention_days     = number
  })
}

variable "name" {
  description = "Nombre del servicio ECS"
  type        = string
}

variable "cpu" {
  description = "CPU de la tarea: 256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU..."
  type        = number
}

variable "memory" {
  description = "Memoria de la tarea en MB"
  type        = number

  validation {
    condition = (
      (var.cpu == 256 && contains([512, 1024, 2048], var.memory)) ||
      (var.cpu == 512 && var.memory >= 1024 && var.memory <= 4096 && var.memory % 1024 == 0) ||
      (var.cpu == 1024 && var.memory >= 2048 && var.memory <= 8192 && var.memory % 1024 == 0) ||
      (var.cpu == 2048 && var.memory >= 4096 && var.memory <= 16384 && var.memory % 1024 == 0) ||
      (var.cpu == 4096 && var.memory >= 8192 && var.memory <= 30720 && var.memory % 1024 == 0)
    )
    error_message = "Combinación de CPU y memoria no válida en Fargate (por ejemplo 256 admite 512, 1024 o 2048)."
  }
}

variable "desired_count" {
  description = "Número de tareas (0 = servicio apagado)"
  type        = number
}

variable "single_instance" {
  description = "true para servicios con datos (Kafka, RabbitMQ...): detiene la tarea vieja antes de arrancar la nueva"
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Security groups de la tarea"
  type        = list(string)
}

variable "load_balancers" {
  description = "Target groups donde ECS registra la IP de cada tarea"
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  default = []
}

variable "health_check_grace_period" {
  description = "Segundos que ECS ignora la salud del balanceador después de arrancar una tarea"
  type        = number
  default     = 60
}

variable "containers" {
  description = "Contenedores de la tarea"
  type = list(object({
    name        = string
    image       = string
    essential   = optional(bool, true)
    ports       = optional(list(number), [])
    environment = optional(map(string), {})
    secrets     = optional(map(string), {}) # VARIABLE => ARN del parámetro SSM
    entry_point = optional(list(string))
    command     = optional(list(string))
    health_check = optional(object({
      command      = list(string)
      interval     = optional(number, 30)
      timeout      = optional(number, 5)
      retries      = optional(number, 3)
      start_period = optional(number, 60)
    }))
    stop_timeout = optional(number)
    restart      = optional(bool, false) # reinicia el contenedor si se cae (sin reemplazar la tarea)
  }))
}