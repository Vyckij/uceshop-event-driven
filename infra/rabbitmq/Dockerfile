# =====================================================================
# RabbitMQ para AWS (ECS Fargate)
# La imagen oficial + los plugins de consola (15672) y métricas (15692).
# En local, Docker Compose monta el mismo archivo enabled_plugins.
# =====================================================================
FROM rabbitmq:3.13-management

COPY --chown=rabbitmq:rabbitmq enabled_plugins /etc/rabbitmq/enabled_plugins

# 5672 = AMQP (consumer) · 15672 = consola web · 15692 = métricas Prometheus
EXPOSE 5672 15672 15692
