# =====================================================================
# Grafana para AWS (ECS Fargate)
# La imagen oficial + el dashboard "UCEShop · Flujo de pedidos" y la
# fuente de datos de AWS. La contraseña del administrador NO va aquí:
# llega desde SSM como variable de entorno (GF_SECURITY_ADMIN_PASSWORD).
# La imagen oficial ya corre con un usuario sin privilegios (472).
# =====================================================================
FROM grafana/grafana:13.2

# Proveedor de dashboards (el mismo que en local)
COPY provisioning/dashboards/dashboards.yml /etc/grafana/provisioning/dashboards/dashboards.yml

# Fuente de datos de AWS (reemplaza a la local)
COPY aws/datasource-aws.yml /etc/grafana/provisioning/datasources/datasource.yml

# El dashboard en JSON
COPY dashboards/ /etc/grafana/dashboards/

ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/uceshop-overview.json \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false

EXPOSE 3000
