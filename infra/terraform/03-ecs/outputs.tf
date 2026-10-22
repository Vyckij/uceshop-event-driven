# =====================================================================
# 03-ecs · salidas
# Para copiar un comando: terraform output -raw comando_estado_servicios
# =====================================================================

output "nlb" {
  description = "NLB interno que reemplaza a Cloud Map (04-exposicion lo busca por su nombre)"
  value = {
    name     = aws_lb.internal.name
    dns_name = aws_lb.internal.dns_name
    arn      = aws_lb.internal.arn
  }
}

output "internal_endpoints" {
  description = "Dirección interna de cada servicio (host:puerto)"
  value       = local.endpoint
}

output "ecs_services" {
  description = "Servicios ECS creados"
  value = [
    module.kafka.service_name,
    module.rabbitmq.service_name,
    module.producer.service_name,
    module.consumer.service_name,
    module.prometheus.service_name,
    module.grafana.service_name,
    module.dashboard.service_name,
  ]
}

output "task_definitions" {
  description = "Task definition (con revisión) de cada servicio"
  value = {
    "kafka"            = module.kafka.task_definition_arn
    "rabbitmq"         = module.rabbitmq.task_definition_arn
    "producer-service" = module.producer.task_definition_arn
    "consumer-service" = module.consumer.task_definition_arn
    "prometheus"       = module.prometheus.task_definition_arn
    "grafana"          = module.grafana.task_definition_arn
    "dashboard"        = module.dashboard.task_definition_arn
  }
}

output "log_groups" {
  description = "Logs de cada servicio en CloudWatch"
  value = {
    "kafka"            = module.kafka.log_group_name
    "rabbitmq"         = module.rabbitmq.log_group_name
    "producer-service" = module.producer.log_group_name
    "consumer-service" = module.consumer.log_group_name
    "prometheus"       = module.prometheus.log_group_name
    "grafana"          = module.grafana.log_group_name
    "dashboard"        = module.dashboard.log_group_name
  }
}

output "target_groups" {
  description = "Target groups del NLB interno"
  value       = { for k, tg in aws_lb_target_group.nlb : k => tg.arn }
}

output "images" {
  description = "Imagen que usa cada contenedor"
  value       = local.images
}

output "comando_estado_servicios" {
  description = "Tareas deseadas y en ejecución de cada servicio"
  value       = "aws ecs describe-services --region ${var.aws_region} --cluster ${data.aws_ecs_cluster.this.cluster_name} --services ${join(" ", sort(keys(var.services)))} --query \"services[].[serviceName,status,desiredCount,runningCount,deployments[0].rolloutState]\" --output table"
}

output "comandos_salud_targets" {
  description = "Salud de las tareas en cada target group del NLB (healthy = lista)"
  value = {
    for k, tg in aws_lb_target_group.nlb :
    k => "aws elbv2 describe-target-health --region ${var.aws_region} --target-group-arn ${tg.arn} --query \"TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]\" --output table"
  }
}

output "comando_ver_ips" {
  description = "IP pública y privada de cada tarea (las consolas también abren directo en la IP pública, solo desde admin_cidrs de 02)"
  value       = "aws ec2 describe-network-interfaces --region ${var.aws_region} --filters \"Name=vpc-id,Values=${data.aws_vpc.this.id}\" \"Name=group-name,Values=${local.name_prefix}-*\" --query \"NetworkInterfaces[?Association.PublicIp].[Groups[0].GroupName,Association.PublicIp,PrivateIpAddress]\" --output table"
}