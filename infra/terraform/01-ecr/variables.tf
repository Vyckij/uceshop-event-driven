# =====================================================================
# 01-ecr · variables (todas tienen valor por defecto: no hace falta .tfvars)
# =====================================================================

variable "aws_region" {
  description = "Región de AWS. Learner Lab solo permite us-east-1 y us-west-2."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo de los repositorios: <project>/<servicio>"
  type        = string
  default     = "uceshop"
}

variable "repositories" {
  description = "Servicios que tendrán su propio repositorio en ECR"
  type        = list(string)
  default = [
    "producer-service",
    "consumer-service",
    "dashboard",
    "kafka",
    "kafka-exporter",
    "rabbitmq",
    "prometheus",
    "grafana",
  ]
}

variable "images_to_keep" {
  description = "Cuántas imágenes conservar por repositorio; las más antiguas se borran solas"
  type        = number
  default     = 5
}
