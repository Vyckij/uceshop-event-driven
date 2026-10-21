/* =====================================================================
 * UCEShop Dashboard · CONFIGURACIÓN
 *
 * Este es el ÚNICO archivo que cambias al pasar de tu PC a AWS.
 * El resto de la aplicación (app.js) lee todas las URLs desde aquí.
 *
 * Dos tipos de URL:
 *   1) APIs que el dashboard CONSULTA (producer, consumer, Prometheus).
 *      Son rutas RELATIVAS que pasan por el Nginx del dashboard
 *      (mismo origen = el navegador no bloquea nada por CORS).
 *   2) Consolas web que el dashboard solo ABRE en otra pestaña
 *      (RabbitMQ, Prometheus, Grafana).
 * ===================================================================== */

// Host desde el que se abrió el dashboard: "localhost" en tu PC,
// o el DNS público de la EC2 / del balanceador en AWS.
// Así no queda ningún "localhost" fijo en el código.
const CURRENT_HOST = window.location.hostname || "localhost";

const CONFIG = Object.freeze({

  // ---------------------------------------------------------------
  // 1) APIs (pasan por el proxy Nginx → mismo origen, sin CORS)
  // ---------------------------------------------------------------
  PRODUCER_URL: "/api/producer",          // POST /orders, GET /actuator/health
  CONSUMER_URL: "/api/consumer",          // GET /processed-orders, GET /actuator/health
  PROMETHEUS_API_URL: "/api/prometheus",  // GET /api/v1/query

  // ---------------------------------------------------------------
  // 2) Consolas web (se abren en una pestaña nueva)
  // ---------------------------------------------------------------
  RABBITMQ_URL: `http://${CURRENT_HOST}:15672`,
  PROMETHEUS_URL: `http://${CURRENT_HOST}:9090`,
  GRAFANA_URL: `http://${CURRENT_HOST}:3000`,

  // ---------------------------------------------------------------
  // Comportamiento
  // ---------------------------------------------------------------
  REFRESH_INTERVAL_MS: 5000,   // actualización automática (5 segundos)
  REQUEST_TIMEOUT_MS: 15000    // el producer puede esperar hasta 15 s a Kafka
});

/* =====================================================================
 * EJEMPLOS PARA AWS (copia el bloque que corresponda y reemplaza)
 *
 * A) Dashboard en ECS/Fargate o EC2 detrás de un ALB (RECOMENDADO):
 *    Las 3 APIs NO cambian (siguen siendo /api/...).
 *    Solo cambian las consolas, porque en AWS tienen su propia dirección:
 *
 *      ENVIRONMENT:    "AWS · ECS Fargate",
 *      RABBITMQ_URL:   "http://<ip-publica-rabbitmq>:15672",
 *      PROMETHEUS_URL: "http://<ip-publica-prometheus>:9090",
 *      GRAFANA_URL:    "http://<ip-publica-grafana>:3000",
 *
 * B) Dashboard en S3 Static Website (otro dominio):
 *    Las APIs deben ser URLs COMPLETAS hacia donde corre el proxy Nginx
 *    (ALB o API Gateway), y ese proxy debe permitir CORS (ver README):
 *
 *      PRODUCER_URL:       "https://<api-o-alb>/api/producer",
 *      CONSUMER_URL:       "https://<api-o-alb>/api/consumer",
 *      PROMETHEUS_API_URL: "https://<api-o-alb>/api/prometheus",
 * ===================================================================== */
