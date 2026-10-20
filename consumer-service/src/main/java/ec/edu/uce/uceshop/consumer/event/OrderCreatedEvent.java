package ec.edu.uce.uceshop.consumer.event;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Copia del CONTRATO del evento que publica el producer-service.
 * <p>
 * Los nombres de los campos deben coincidir exactamente con los del JSON que llega.
 * Los dos servicios no comparten código: cada uno tiene su propia clase del evento.
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
        Instant createdAt
) {

    public static final String TYPE = "ORDER_CREATED";
}
