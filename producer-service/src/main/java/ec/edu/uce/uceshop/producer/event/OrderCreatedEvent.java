package ec.edu.uce.uceshop.producer.event;

import com.fasterxml.jackson.annotation.JsonFormat;
import ec.edu.uce.uceshop.producer.model.Order;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Evento que se publica en el tópico "orders" de Kafka cada vez que se crea un pedido.
 * <p>
 * Es el CONTRATO entre producer-service y consumer-service: ambos deben coincidir
 * en estos nombres de campos. Viaja como JSON.
 *
 * @param eventId   identificador único del EVENTO (sirve al consumer para detectar duplicados)
 * @param eventType tipo de evento, siempre "ORDER_CREATED"
 * @param orderId   identificador del PEDIDO (también se usa como key del mensaje en Kafka)
 * @param createdAt se envía como texto ISO-8601, por ejemplo "2026-10-19T23:40:12.345Z"
 */
public record OrderCreatedEvent(
        UUID eventId,
        String eventType,
        UUID orderId,
        String customerId,
        String product,
        Integer quantity,
        BigDecimal unitPrice,
        BigDecimal total,
        @JsonFormat(shape = JsonFormat.Shape.STRING) Instant createdAt
) {

    public static final String TYPE = "ORDER_CREATED";

    /** Construye el evento a partir de un pedido ya guardado en la base de datos. */
    public static OrderCreatedEvent from(Order order) {
        return new OrderCreatedEvent(
                UUID.randomUUID(),
                TYPE,
                order.getId(),
                order.getCustomerId(),
                order.getProduct(),
                order.getQuantity(),
                order.getUnitPrice(),
                order.getTotal(),
                order.getCreatedAt()
        );
    }
}
