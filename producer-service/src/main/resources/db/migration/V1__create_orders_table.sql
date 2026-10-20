-- =====================================================================
-- V1: tabla de pedidos del producer-service (base producerdb)
-- Flyway ejecuta este script UNA sola vez y lo registra en la tabla
-- flyway_schema_history. Nunca edites un script ya ejecutado:
-- para cambios futuros crea V2__..., V3__..., etc.
-- =====================================================================

-- "order" es palabra reservada en SQL, por eso la tabla se llama "orders"
CREATE TABLE orders (
    id           UUID           PRIMARY KEY,
    customer_id  VARCHAR(50)    NOT NULL,
    product      VARCHAR(120)   NOT NULL,
    quantity     INTEGER        NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(10, 2) NOT NULL CHECK (unit_price > 0),
    total        NUMERIC(14, 2) NOT NULL,
    status       VARCHAR(20)    NOT NULL,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- Índice para buscar rápido los pedidos de un cliente
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
