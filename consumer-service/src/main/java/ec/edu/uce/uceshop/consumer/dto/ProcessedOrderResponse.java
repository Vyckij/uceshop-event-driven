package ec.edu.uce.uceshop.consumer.dto;

import ec.edu.uce.uceshop.consumer.model.ProcessedOrder;
import ec.edu.uce.uceshop.consumer.model.ProcessingStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Respuesta JSON de GET /processed-orders.
 */
public record ProcessedOrderResponse(
        UUID orderId,
        UUID eventId,
        String customerId,
        String product,
        Integer quantity,
        BigDecimal total,
        ProcessingStatus status,
        Integer kafkaPartition,
        Long kafkaOffset,
        Instant processedAt
) {

    public static ProcessedOrderResponse from(ProcessedOrder entity) {
        return new ProcessedOrderResponse(
                entity.getOrderId(),
                entity.getEventId(),
                entity.getCustomerId(),
                entity.getProduct(),
                entity.getQuantity(),
                entity.getTotal(),
                entity.getStatus(),
                entity.getKafkaPartition(),
                entity.getKafkaOffset(),
                entity.getProcessedAt()
        );
    }
}
