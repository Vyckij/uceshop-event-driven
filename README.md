# uceshop-event-driven
# UCEShop - Arquitectura Orientada a Eventos

## Caso Práctico 2

### Descripción General

UCEShop es una solución basada en una arquitectura orientada a eventos (Event-Driven Architecture) que desacopla la creación y procesamiento de pedidos mediante Apache Kafka y RabbitMQ.

La solución implementa dos microservicios independientes:

- Producer Service
- Consumer Service

Cada servicio posee su propia base de datos PostgreSQL siguiendo el patrón Database per Service.

Además, la solución incorpora:

- Docker Compose
- Health Checks
- Prometheus
- Grafana
- Dashboard Web
- Terraform
- AWS ECR
- AWS ECS Fargate
- AWS RDS
- Amazon API Gateway

---

# Objetivo General

Implementar una arquitectura orientada a eventos para la gestión de pedidos utilizando Apache Kafka y RabbitMQ, desplegable mediante contenedores Docker y preparada para ejecutarse sobre Amazon Web Services.
---

# Arquitectura

```text
                     Dashboard Web
                            │
                            ▼
                   Producer Service
                            │
                            ▼
                    PostgreSQL
                     producerdb
                            │
                            ▼
                   Apache Kafka
                   Topic: orders
                 (3 particiones)
                            │
                            ▼
                   Consumer Service
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
          PostgreSQL              RabbitMQ
          consumerdb         orders.notifications
                                     orders.dlq

                   Prometheus
                        │
                        ▼
                      Grafana
```

---

# Tecnologías Utilizadas

## Backend

- Java 21
- Spring Boot 3
- Spring Data JPA
- Spring Kafka
- Spring AMQP
- Flyway

## Mensajería

- Apache Kafka
- RabbitMQ

## Base de Datos

- PostgreSQL

## Observabilidad

- Spring Actuator
- Prometheus
- Grafana

## Contenedores

- Docker
- Docker Compose

## Frontend

- HTML5
- CSS3
- Bootstrap 5
- JavaScript

## Cloud

- Amazon ECR
- Amazon ECS Fargate
- Amazon RDS PostgreSQL
- Amazon API Gateway

## Infraestructura como Código

- Terraform

---

# Estructura del Proyecto

```text
uceshop-event-driven
│
├── producer-service/
├── consumer-service/
├── infra/
│   ├── prometheus/
│   ├── grafana/
│   └── rabbitmq/
│
├── uceshop-dashboard/
│
├── docker-compose.yml
├── .env
├── .env.example
└── README.md
```

---

# Servicios Disponibles

| Servicio | Puerto |
|----------|---------|
| Producer Service | 8080 |
| Consumer Service | 8081 |
| Kafka | 9094 |
| RabbitMQ | 5672 |
| RabbitMQ UI | 15672 |
| Prometheus | 9090 |
| Grafana | 3000 |
| Dashboard | 8088 |

---

# Ejecución Local

## Levantar el entorno

```bash
docker compose up -d --build
```

## Verificar estado

```bash
docker compose ps
```

## Detener entorno

```bash
docker compose down
```

---

# Flujo del Sistema

1. El usuario envía un pedido.
2. Producer Service valida la solicitud.
3. Producer Service guarda el pedido en producerdb.
4. Producer Service publica un evento en Kafka.
5. Consumer Service consume el evento.
6. Consumer Service procesa la información.
7. Consumer Service guarda los datos en consumerdb.
8. Consumer Service publica una notificación en RabbitMQ.
9. Prometheus captura métricas.
10. Grafana visualiza métricas y monitoreo.

---

# Ejemplo de Solicitud

## Endpoint

```http
POST /orders
```

## Body

```json
{
  "customerId": "C-001",
  "product": "Laptop Lenovo",
  "quantity": 2,
  "unitPrice": 750.50
}
```

---

# Observabilidad

## Spring Actuator

Endpoints:

```text
/actuator/health
/actuator/health/liveness
/actuator/prometheus
```

## Prometheus

Métricas monitoreadas:

- Producer Service
- Consumer Service
- Kafka
- RabbitMQ
- JVM
- HTTP Requests

## Grafana

Dashboard:

```text
UCEShop - Flujo de Pedidos
```

---

# Dockerización

Servicios incluidos:

```text
producer-service
consumer-service
producer-db
consumer-db
kafka
rabbitmq
prometheus
grafana
kafka-exporter
dashboard
```
---

# AWS

La solución está preparada para desplegarse utilizando:

## Amazon ECR

Repositorios:

- producer-service
- consumer-service
- dashboard

## Amazon ECS Fargate

Servicios:

- producer-service
- consumer-service
- dashboard

## Amazon RDS PostgreSQL

Bases de datos:

- producerdb
- consumerdb

## Amazon API Gateway

Punto de entrada público para las APIs.

---

# Evidencias Requeridas

## Docker

```bash
docker compose ps
```

## RabbitMQ

- orders.notifications
- orders.dlq

## Prometheus

```text
http://localhost:9090/targets
```

## Grafana

Dashboard principal funcionando.

```
```

# Autor

Jessica Lizbeth Victoria Minda

UCEShop - Arquitectura Orientada a Eventos

2026