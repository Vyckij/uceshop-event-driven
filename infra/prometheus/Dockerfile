# =====================================================================
# Prometheus para AWS (ECS Fargate)
# La imagen oficial + la configuración de AWS (descubrimiento por DNS).
# En local, Docker Compose sigue usando prometheus.yml montado.
# La imagen oficial ya corre con un usuario sin privilegios (nobody).
# =====================================================================
FROM prom/prometheus:v3.13.4

COPY prometheus-aws.yml /etc/prometheus/prometheus.yml

# Sin --web.enable-lifecycle: en AWS nadie puede apagar Prometheus por la red.
# Guarda 3 días de métricas (el disco de Fargate es temporal).
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--storage.tsdb.retention.time=3d"]

EXPOSE 9090
