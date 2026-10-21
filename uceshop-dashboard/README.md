# UCEShop Dashboard

Interfaz web para la **demostración y defensa** del Caso Práctico 2 (UCEShop): una arquitectura orientada a eventos con Spring Boot, Kafka, RabbitMQ, PostgreSQL, Docker, Prometheus y Grafana.

Desde una sola página puedes:

1. **Crear pedidos** (`POST /orders`) y ver el resultado y el tiempo de respuesta.
2. Ver los **pedidos procesados** por el consumer (`GET /processed-orders`), con filtro por producto y actualización cada 5 segundos.
3. Ver el **estado** (UP/DOWN) del producer y del consumer (`/actuator/health`).
4. Ver **métricas** desde Prometheus: pedidos publicados, procesados, fallidos y notificaciones.
5. Abrir **RabbitMQ, Prometheus y Grafana** en otra pestaña.
6. Mostrar el **diagrama de la arquitectura**.

---

## Tecnologías

- HTML5, CSS3 y **JavaScript puro** (sin frameworks)
- **Bootstrap 5.3** y Bootstrap Icons (desde CDN)
- **Nginx** (imagen `nginx-unprivileged`, sin root) para servir los archivos y hacer de proxy

---

## Estructura

```
uceshop-dashboard/
├── index.html                    ← la página (6 secciones)
├── css/
│   └── style.css                 ← tema azul oscuro + blanco
├── js/
│   ├── config.js                 ← TODAS las URLs (único archivo a editar para AWS)
│   └── app.js                    ← lógica: llamadas a las APIs y actualización
├── assets/
│   └── favicon.svg               ← logo
├── nginx/
│   └── default.conf.template     ← Nginx: archivos estáticos + proxy a las APIs
├── Dockerfile                    ← imagen del dashboard (Compose, EC2, ECS)
├── .dockerignore
└── README.md
```

---

## Cómo se conecta con los servicios (y por qué no hay problemas de CORS)

Por seguridad, un navegador **bloquea** las llamadas de una página a otro "origen" (otro dominio o puerto) si ese servidor no lo autoriza. Eso se llama **CORS**. El dashboard (puerto 8088) y el producer (puerto 8080) son orígenes distintos.

Para no tener que modificar los servicios Java, el dashboard incluye un **Nginx que hace de proxy**:

```
Navegador ──▶ Nginx del dashboard (:8088)
                ├── /                        → index.html, css, js
                ├── /api/producer/...        → producer-service:8080
                ├── /api/consumer/...        → consumer-service:8081
                └── /api/prometheus/...      → prometheus:9090 (solo lectura)
```

El navegador solo habla con Nginx (mismo origen) y Nginx reenvía la petición al servicio correspondiente. Por eso, en `config.js` las APIs son rutas relativas como `/api/producer`.

Por seguridad, Nginx **solo deja pasar** las rutas que usa el dashboard: `POST /orders`, `GET /orders/{id}`, `GET /processed-orders`, `/actuator/health` y las consultas de Prometheus. Todo lo demás responde 404.

---

## Ejecutar en local

### Requisitos
El stack de las fases anteriores funcionando con Docker Compose (Kafka, RabbitMQ, bases de datos, producer, consumer, Prometheus y Grafana).

### Pasos

1. Coloca la carpeta `uceshop-dashboard/` en la **raíz** del repositorio, junto a `docker-compose.yml`.
2. Agrega el servicio `dashboard` al `docker-compose.yml` y la variable `DASHBOARD_PORT=8088` a tu `.env`.
3. Construye y levanta el dashboard:
   ```bash
   docker compose up -d --build dashboard
   ```
4. Abre **http://localhost:8088**

> ⚠️ No abras `index.html` con doble clic: así el navegador lo carga como `file://`, no hay proxy y las APIs no responden. La página muestra un aviso si lo haces.

### Si cambias un archivo del dashboard
Los archivos van dentro de la imagen, así que hay que reconstruirla:
```bash
docker compose up -d --build dashboard
```

---

## config.js

| Clave | Valor local | Para qué |
|---|---|---|
| `ENVIRONMENT` | `Local · Docker Compose` | Texto de la barra superior |
| `PRODUCER_URL` | `/api/producer` | API del producer (a través del proxy) |
| `CONSUMER_URL` | `/api/consumer` | API del consumer (a través del proxy) |
| `PROMETHEUS_API_URL` | `/api/prometheus` | Consultas de métricas (a través del proxy) |
| `RABBITMQ_URL` | `http://<host>:15672` | Botón "RabbitMQ" |
| `PROMETHEUS_URL` | `http://<host>:9090` | Botón "Prometheus" |
| `GRAFANA_URL` | `http://<host>:3000` | Botón "Grafana" |
| `REFRESH_INTERVAL_MS` | `5000` | Actualización automática |
| `REQUEST_TIMEOUT_MS` | `15000` | Tiempo máximo de espera por petición |

`<host>` se toma automáticamente de la dirección del navegador (`window.location.hostname`), así que no hay ningún `localhost` fijo en el código.

---

## Guion sugerido para la defensa

1. **Arquitectura:** recorre el diagrama de la sección 6.
2. **Estado:** muestra que producer y consumer están 🟢 UP.
3. **Pedido válido:** pulsa *Ejemplo válido* y luego *Enviar Pedido*. Verás la respuesta **202** y su tiempo; en unos segundos el pedido aparece en la tabla con su **partición** de Kafka.
4. **Datos inválidos:** envía el formulario vacío. Verás el **400** con los mensajes de validación del producer.
5. **DLQ:** pulsa *Ejemplo DLQ* (150 unidades) y envíalo. El producer responde 202, pero el consumer lo rechaza: **no** aparece en la tabla, sube *Eventos fallidos* y el mensaje queda en `orders.dlq` (ábrelo con el botón de RabbitMQ).
6. **Resiliencia:** ejecuta `docker compose stop consumer-service`. La tarjeta pasa a 🔴 DOWN, pero sigues pudiendo crear pedidos (202). Ejecuta `docker compose start consumer-service`: procesa los pendientes y aparecen en la tabla.
7. **Observabilidad:** abre Grafana con el botón de la sección Monitoreo.

---

## Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| La página se ve sin estilos | Bootstrap se carga desde internet (CDN): revisa tu conexión |
| Todo aparece en 🔴 DOWN | El contenedor `dashboard` no alcanza a los servicios: revisa `docker compose ps` y `docker compose logs dashboard` |
| Métricas en "—" y "sin conexión" | Prometheus está apagado: `docker compose ps prometheus` |
| Los botones de monitoreo no abren | Revisa las 3 URLs de consolas en `config.js` |
| Cambié `config.js` y no se nota | Reconstruye la imagen (`--build`) y recarga con Ctrl+F5 |

---

# Despliegue en AWS

Pasos comunes a todas las opciones: el dashboard es una **imagen Docker**. Se construye para la arquitectura de Fargate y EC2 (`linux/amd64`) y se sube a **Amazon ECR**:

```bash
# 1) Variables (cambia la región y tu número de cuenta)
REGION=us-east-1
ACCOUNT_ID=123456789012
REPO=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/uceshop/dashboard

# 2) Crear el repositorio (solo la primera vez)
aws ecr create-repository --repository-name uceshop/dashboard --region $REGION

# 3) Iniciar sesión de Docker en ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# 4) Construir para amd64 (importante en Mac con chip M) y subir
docker build --platform linux/amd64 -t $REPO:1.0.0 .
docker push $REPO:1.0.0
```

La misma imagen sirve en todos lados: lo que cambia son sus **variables de entorno**.

| Variable | Local (Compose) | AWS (ECS con Cloud Map) |
|---|---|---|
| `PRODUCER_UPSTREAM` | `producer-service:8080` | `producer-service.uceshop.local:8080` |
| `CONSUMER_UPSTREAM` | `consumer-service:8081` | `consumer-service.uceshop.local:8081` |
| `PROMETHEUS_UPSTREAM` | `prometheus:9090` | `prometheus.uceshop.local:9090` |
| `NGINX_RESOLVER` | `127.0.0.11` (DNS de Docker) | `169.254.169.253` (DNS de la VPC) |
| `CORS_ALLOW_ORIGIN` | vacío | vacío, salvo que uses S3 (ver más abajo) |

---

## Opción A · ECS Fargate detrás de un Application Load Balancer (recomendada)

Es la opción que encaja con el enunciado (despliegue en ECS Fargate) y **no requiere cambiar las APIs de `config.js`**, porque el navegador sigue hablando con el mismo origen: el ALB.

```
Navegador ──▶ ALB (HTTP :80) ──▶ dashboard (Fargate :8080) ──▶ producer / consumer / prometheus
                                                                (DNS privado *.uceshop.local)
```

1. **Imagen en ECR**: sigue los pasos comunes.
2. **Task definition** `uceshop-dashboard`:
   - Imagen: `…/uceshop/dashboard:1.0.0` · CPU 0.25 vCPU · Memoria 0.5 GB
   - Puerto del contenedor: **8080**
   - Variables de entorno: las de la columna **AWS** de la tabla anterior
   - Health check: `CMD-SHELL, wget -q --spider http://localhost:8080/health || exit 1`
   - Logs: `awslogs` hacia CloudWatch
3. **Target group**: tipo **IP**, protocolo HTTP, puerto **8080**, health check en la ruta **`/health`**.
4. **ALB**:
   - Listener HTTP:80 con regla por defecto hacia el target group del dashboard.
   - Si el mismo ALB también atiende a API Gateway, agrega una regla de mayor prioridad para `/orders*` hacia el target group del producer.
5. **Servicio ECS** `dashboard`: 1 tarea, en las subredes del clúster, asociado al target group.
6. **Security groups**:
   - ALB → dashboard: puerto 8080.
   - dashboard → producer (8080), consumer (8081) y prometheus (9090).
7. **`config.js`**: las APIs no cambian. Solo actualiza `ENVIRONMENT` y las 3 URLs de consolas (RabbitMQ, Prometheus, Grafana) con las direcciones donde las publiques en AWS. Después, reconstruye y vuelve a subir la imagen.
8. Abre el **DNS del ALB** (`http://uceshop-alb-123.us-east-1.elb.amazonaws.com`).

**Si todo el tráfico debe pasar por Amazon API Gateway:** en tu HTTP API crea la ruta **`$default`** hacia el listener del ALB, a través del VPC Link. Abre el dashboard con la URL de API Gateway (`https://<id>.execute-api.<region>.amazonaws.com/`). Como las APIs son rutas relativas, funciona sin cambiar nada.

---

## Opción B · AWS EC2

### B1. Con Docker (más simple)

1. **Lanza una instancia**: Amazon Linux 2023, `t3.small`, en una subred pública de la **misma VPC** que los servicios.
2. **Security group de la EC2**:
   - Entrada: puerto **22** solo desde tu IP; puerto **80** desde tu IP (o desde 0.0.0.0/0 para una demo pública).
   - Además, permite que esta EC2 llegue a producer (8080), consumer (8081) y prometheus (9090) en sus security groups.
3. **Instala Docker** (conectado por SSH):
   ```bash
   sudo dnf install -y docker
   sudo systemctl enable --now docker
   sudo usermod -aG docker ec2-user   # cierra la sesión SSH y vuelve a entrar
   ```
4. **Descarga la imagen desde ECR** (la EC2 necesita un *IAM role* con permiso de lectura de ECR, por ejemplo `AmazonEC2ContainerRegistryReadOnly`):
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
   ```
5. **Ejecuta el contenedor** apuntando a los servicios. Si están en ECS con Cloud Map, usa sus nombres `*.uceshop.local`; también sirven IPs privadas o el DNS de un ALB interno:
   ```bash
   docker run -d --name uceshop-dashboard --restart unless-stopped -p 80:8080 \
     -e PRODUCER_UPSTREAM=producer-service.uceshop.local:8080 \
     -e CONSUMER_UPSTREAM=consumer-service.uceshop.local:8081 \
     -e PROMETHEUS_UPSTREAM=prometheus.uceshop.local:9090 \
     -e NGINX_RESOLVER=169.254.169.253 \
     <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/uceshop/dashboard:1.0.0
   ```
6. Abre `http://<DNS-público-de-la-EC2>`.

### B2. Con Nginx instalado directamente (sin Docker)

```bash
sudo dnf install -y nginx gettext          # gettext trae el comando envsubst
sudo cp -r index.html css js assets /usr/share/nginx/html/

# Genera la configuración reemplazando las variables de la plantilla
export PRODUCER_UPSTREAM=producer-service.uceshop.local:8080
export CONSUMER_UPSTREAM=consumer-service.uceshop.local:8081
export PROMETHEUS_UPSTREAM=prometheus.uceshop.local:9090
export NGINX_RESOLVER=169.254.169.253
export CORS_ALLOW_ORIGIN=""
envsubst '${PRODUCER_UPSTREAM} ${CONSUMER_UPSTREAM} ${PROMETHEUS_UPSTREAM} ${NGINX_RESOLVER} ${CORS_ALLOW_ORIGIN}' \
  < nginx/default.conf.template | sudo tee /etc/nginx/conf.d/uceshop.conf

sudo nginx -t                               # comprueba la configuración
sudo systemctl enable --now nginx
```

La plantilla escucha en el puerto **8080**: abre ese puerto en el security group y entra a `http://<DNS-público>:8080`.

---

## Opción C · S3 Static Website Hosting

S3 solo sirve archivos: **no puede hacer de proxy**. Por eso, en esta opción el dashboard debe llamar a un proxy que esté en otro lugar (el dashboard de la Opción A detrás del ALB, o API Gateway), y ese proxy debe permitir CORS.

1. **Crea un bucket**, por ejemplo `uceshop-dashboard-<tu-nombre>`, en tu región.
2. En *Permissions*, desactiva **Block all public access**: el sitio será público.
3. Agrega esta **bucket policy** de solo lectura (cambia el nombre del bucket):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Sid": "LecturaPublica",
       "Effect": "Allow",
       "Principal": "*",
       "Action": "s3:GetObject",
       "Resource": "arn:aws:s3:::uceshop-dashboard-<tu-nombre>/*"
     }]
   }
   ```
4. En *Properties*, activa **Static website hosting** con *Index document* `index.html`. Copia la URL del sitio, por ejemplo `http://uceshop-dashboard-<tu-nombre>.s3-website-us-east-1.amazonaws.com`.
5. **Edita `config.js`**: las APIs pasan a ser URLs completas hacia el proxy (ALB o API Gateway):
   ```js
   PRODUCER_URL:       "http://<DNS-del-ALB>/api/producer",
   CONSUMER_URL:       "http://<DNS-del-ALB>/api/consumer",
   PROMETHEUS_API_URL: "http://<DNS-del-ALB>/api/prometheus",
   ```
6. **Permite CORS en el proxy**: en la task definition del dashboard de ECS, define `CORS_ALLOW_ORIGIN` con la URL exacta del sitio S3 (sin `/` final) y redespliega el servicio.
7. **Sube los archivos** (desde la carpeta `uceshop-dashboard`):
   ```bash
   aws s3 sync . s3://uceshop-dashboard-<tu-nombre> \
     --exclude "Dockerfile" --exclude ".dockerignore" --exclude "nginx/*" --exclude "README.md"
   ```
8. Abre la URL del sitio S3.

> **Ojo con HTTP y HTTPS:** el sitio de S3 usa `http://`. Si luego lo pones detrás de CloudFront con `https://`, las APIs también deben usar `https://`. El navegador bloquea las llamadas de una página HTTPS a una API HTTP (*mixed content*).

> Para un sitio real se usa **CloudFront con Origin Access Control** (bucket privado + HTTPS). El bucket público es suficiente para una demostración.

---

## Notas de seguridad

- El código nunca usa `innerHTML` con datos recibidos: todo se muestra con `textContent`, así que un producto llamado `<script>…</script>` se ve como texto y no se ejecuta.
- El proxy solo expone las rutas necesarias y bloquea el resto (404). Las consultas a Prometheus son solo `GET`.
- El contenedor de Nginx corre **sin root** (imagen `nginx-unprivileged`).
- No publiques RabbitMQ, Prometheus ni Grafana a todo internet: limita sus security groups a tu IP.
