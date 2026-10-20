package ec.edu.uce.uceshop.consumer.messaging;

import ec.edu.uce.uceshop.consumer.model.ProcessedOrder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Mensaje que se publica en la cola orders.notifications cuando un pedido
 * se procesa con éxito. Un futuro "notification-service" lo leería para enviar
 * un correo o un SMS al cliente.
 */
public record OrderNotification(
        String notificationType,
        UUID orderId,
        String customerId,
        String product,
        Integer quantity,
        BigDecimal total,
        String message,
        Instant processedAt
) {

    public static final String TYPE = "ORDER_PROCESSED";

    public static OrderNotification from(ProcessedOrder order) {
        String text = "Tu pedido de " + order.getQuantity() + " x " + order.getProduct()
                + " fue procesado. Total: " + order.getTotal();

        return new OrderNotification(
                TYPE,
                order.getOrderId(),
                order.getCustomerId(),
                order.getProduct(),
                order.getQuantity(),
                order.getTotal(),
                text,
                order.getProcessedAt()
        );
    }
}
