# =====================================================================
# 03-ecs · security groups
#
# Tráfico permitido:
#   VPC (tareas y ALB) -> NLB interno, en los puertos de sus listeners
#   NLB interno        -> cada tarea, solo en el puerto de su servicio
#
# Los security groups de las tareas son los de 02-plataforma; aquí solo
# se les agrega la entrada desde el NLB. Las descripciones van sin
# tildes porque AWS no las acepta.
# =====================================================================

resource "aws_security_group" "nlb" {
  name        = "${local.name_prefix}-nlb"
  description = "NLB interno: descubrimiento de servicios"
  vpc_id      = data.aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-nlb"
  }
}

# Entrada al NLB desde cualquier dirección de la VPC
resource "aws_vpc_security_group_ingress_rule" "nlb_from_vpc" {
  for_each = local.nlb_endpoints

  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = data.aws_vpc.this.cidr_block
  ip_protocol       = "tcp"
  from_port         = each.value.listener_port
  to_port           = each.value.listener_port
  description       = "VPC hacia ${each.key}"

  tags = {
    Name = "nlb-${each.key}"
  }
}

# Salida del NLB hacia las tareas (tráfico y health checks)
resource "aws_vpc_security_group_egress_rule" "nlb_to_vpc" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = data.aws_vpc.this.cidr_block
  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
  description       = "NLB hacia las tareas de la VPC"

  tags = {
    Name = "nlb-egress"
  }
}

# Entrada a cada tarea desde el NLB
resource "aws_vpc_security_group_ingress_rule" "task_from_nlb" {
  for_each = local.nlb_endpoints

  security_group_id            = data.aws_security_group.this[local.service_security_group[each.value.service]].id
  referenced_security_group_id = aws_security_group.nlb.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "Desde el NLB interno (${each.key})"

  tags = {
    Name = "from-nlb-${each.key}"
  }
}