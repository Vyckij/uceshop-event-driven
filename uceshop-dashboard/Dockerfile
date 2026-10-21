# =====================================================================
# UCEShop Dashboard · imagen Docker
# Nginx sin privilegios (no-root) que sirve el dashboard y hace de proxy.
# Sirve igual para Docker Compose, EC2 con Docker y ECS Fargate.
# =====================================================================
FROM nginxinc/nginx-unprivileged:1.30-alpine

# Valores por defecto para Docker Compose (local).
# En AWS se cambian con variables de entorno, SIN reconstruir la imagen.
ENV PRODUCER_UPSTREAM=producer-service:8080 \
    CONSUMER_UPSTREAM=consumer-service:8081 \
    PROMETHEUS_UPSTREAM=prometheus:9090 \
    NGINX_RESOLVER=127.0.0.11 \
    CORS_ALLOW_ORIGIN=""

# Plantilla de configuración: al arrancar, Nginx reemplaza las ${VARIABLES}
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Archivos del dashboard
COPY index.html /usr/share/nginx/html/index.html
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/
COPY assets/ /usr/share/nginx/html/assets/

# Nginx sin privilegios escucha en el 8080 (no puede usar el 80)
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
  CMD wget -q --spider http://localhost:8080/health || exit 1
