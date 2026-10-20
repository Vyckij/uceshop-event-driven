-- =====================================================================
-- V1: pedidos procesados por el consumer-service (base consumerdb)
-- Esta base es INDEPENDIENTE de producerdb: tiene su propia tabla
-- flyway_schema_history, por eso este script también es V1.
-- =====================================================================

CREATE TABLE processed_orders (
    -- Identificador interno; PostgreSQL lo genera solo (1, 2, 3...)
    id               BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Datos del evento recibido
    event_id         UUID           NOT NULL,
    order_id         UUID           NOT NULL,
    customer_id      VARCHAR(50)    NOT NULL,
    product          VARCHAR(120)   NOT NULL,
    quantity         INTEGER        NOT NULL,
    total            NUMERIC(14, 2) NOT NULL,

    -- Resultado del procesamiento
    status           VARCHAR(20)    NOT NULL,

    -- De dónde salió el mensaje en Kafka (evidencia de las 3 particiones)
    kafka_partition  INTEGER        NOT NULL,
    kafka_offset     BIGINT         NOT NULL,

    processed_at     TIMESTAMPTZ    NOT NULL DEFAULT now(),

    -- IDEMPOTENCIA: la base rechaza guardar dos veces el mismo evento
    CONSTRAINT uk_processed_orders_event_id UNIQUE (event_id)
);

-- Índice para buscar por pedido
CREATE INDEX idx_processed_orders_order_id ON processed_orders (order_id);
