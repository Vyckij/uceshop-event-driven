# =====================================================================
# 03-ecs · permisos (IAM)
#
# AWS Academy (create_iam_roles = false):
#   LabRole es el rol de ejecución y el rol de tarea.
#
# Cuenta normal (create_iam_roles = true):
#   - ejecución: descargar imágenes de ECR, escribir logs y leer las
#     contraseñas de SSM
#   - tarea: lo que usa la aplicación en ejecución (solo ECS Exec)
# =====================================================================

locals {
  lab_role_arn = "arn:${local.partition}:iam::${local.account_id}:role/${var.lab_role_name}"

  execution_role_arn = var.create_iam_roles ? aws_iam_role.task_execution[0].arn : local.lab_role_arn
  task_role_arn      = var.create_iam_roles ? aws_iam_role.task[0].arn : local.lab_role_arn
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------
# Rol de ejecución (lo usa ECS para arrancar la tarea)
# ---------------------------------------------------------------------
resource "aws_iam_role" "task_execution" {
  count = var.create_iam_roles ? 1 : 0

  name               = "${local.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  count = var.create_iam_roles ? 1 : 0

  role       = aws_iam_role.task_execution[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions   = ["ssm:GetParameters"]
    resources = [for p in data.aws_ssm_parameter.secret : p.arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  count = var.create_iam_roles ? 1 : 0

  name   = "read-ssm-secrets"
  role   = aws_iam_role.task_execution[0].id
  policy = data.aws_iam_policy_document.read_secrets.json
}

# ---------------------------------------------------------------------
# Rol de tarea (lo usa la aplicación mientras corre)
# ---------------------------------------------------------------------
resource "aws_iam_role" "task" {
  count = var.create_iam_roles ? 1 : 0

  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_ecs_exec" {
  count = var.create_iam_roles && var.enable_execute_command ? 1 : 0

  name   = "ecs-exec"
  role   = aws_iam_role.task[0].id
  policy = data.aws_iam_policy_document.ecs_exec.json
}