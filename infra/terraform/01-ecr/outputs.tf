# =====================================================================
# 01-ecr · salidas (se ven con "terraform output")
# =====================================================================

output "account_id" {
  description = "Número de la cuenta de Learner Lab"
  value       = data.aws_caller_identity.current.account_id
}

output "registry" {
  description = "Dirección del registro ECR (se usa en docker login y en las etiquetas)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "repository_urls" {
  description = "URL completa de cada repositorio"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
