package ec.edu.uce.uceshop.consumer.model;

import ec.edu.uce.uceshop.consumer.event.OrderCreatedEvent;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/**
 * Entidad JPA: cada objeto es una fila de la tabla "processed_orders" de consumerdb.
 */
@Entity
@Table(name = "processed_orders")
public class ProcessedOrder {

    /** IDENTITY: PostgreSQL genera el número automáticamente al insertar. */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** unique = true documenta en Java la restricción UNIQUE que creó Flyway. */
    @Column(name = "event_id", nullable = false, unique = true)
    private UUID eventId;

    @Column(name = "order_id", nullable = false)
    private UUID orderId;

    @Column(name = "customer_id", nullable = false, length = 50)
    private String customerId;

    @Column(name = "product", nullable = false, length = 120)
    private String product;

    @Column(name = "quantity", nullable = false)
    private Integer quantity;

    @Column(name = "total", nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ProcessingStatus status;

    @Column(name = "kafka_partition", nullable = false)
    private Integer kafkaPartition;

    @Column(name = "kafka_offset", nullable = false)
    private Long kafkaOffset;

    @Column(name = "processed_at", nullable = false)
    private Instant processedAt;

    /** Constructor vacío obligatorio para JPA. */
    protected ProcessedOrder() {
    }

    /**
     * Crea el registro a partir del evento recibido y de su ubicación en Kafka.
     */
    public static ProcessedOrder from(OrderCreatedEvent event, int partition, long offset) {
        ProcessedOrder processed = new ProcessedOrder();
        processed.eventId = event.eventId();
        processed.orderId = event.orderId();
        processed.customerId = event.customerId();
        processed.product = event.product();
        processed.quantity = event.quantity();
        processed.total = event.total();
        processed.status = ProcessingStatus.PROCESSED;
        processed.kafkaPartition = partition;
        processed.kafkaOffset = offset;
        processed.processedAt = Instant.now().truncatedTo(ChronoUnit.MILLIS);
        return processed;
    }

    // ---- Getters ----

    public Long getId() {
        return id;
    }

    public UUID getEventId() {
        return eventId;
    }

    public UUID getOrderId() {
        return orderId;
    }

    public String getCustomerId() {
        return customerId;
    }

    public String getProduct() {
        return product;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public ProcessingStatus getStatus() {
        return status;
    }

    public Integer getKafkaPartition() {
        return kafkaPartition;
    }

    public Long getKafkaOffset() {
        return kafkaOffset;
    }

    public Instant getProcessedAt() {
        return processedAt;
    }
}
