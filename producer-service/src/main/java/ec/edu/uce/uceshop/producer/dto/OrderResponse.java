package ec.edu.uce.uceshop.producer.dto;

import ec.edu.uce.uceshop.producer.model.Order;
import ec.edu.uce.uceshop.producer.model.OrderStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Lo que la API devuelve al cliente. Separarlo de la entidad Order evita exponer
 * detalles internos de la base de datos y permite cambiar uno sin romper el otro.
 */
public record OrderResponse(
        UUID orderId,
        String customerId,
        String product,
        Integer quantity,
        BigDecimal unitPrice,
        BigDecimal total,
        OrderStatus status,
        Instant createdAt
) {

    /** Convierte una entidad Order en la respuesta de la API. */
    public static OrderResponse from(Order order) {
        return new OrderResponse(
                order.getId(),
                order.getCustomerId(),
                order.getProduct(),
                order.getQuantity(),
                order.getUnitPrice(),
                order.getTotal(),
                order.getStatus(),
                order.getCreatedAt()
        );
    }
}
