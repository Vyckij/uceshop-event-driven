package ec.edu.uce.uceshop.producer.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/**
 * Entidad JPA: cada objeto Order corresponde a una fila de la tabla "orders" de producerdb.
 */
@Entity
@Table(name = "orders")
public class Order {

    /** Clave primaria. Hibernate genera un UUID aleatorio al guardar. */
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "customer_id", nullable = false, length = 50)
    private String customerId;

    @Column(name = "product", nullable = false, length = 120)
    private String product;

    @Column(name = "quantity", nullable = false)
    private Integer quantity;

    /** BigDecimal (no double) para que el dinero no tenga errores de redondeo. */
    @Column(name = "unit_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal unitPrice;

    @Column(name = "total", nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    /** Se guarda como texto ("CREATED"), no como número. */
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private OrderStatus status;

    /** Instant = fecha y hora en UTC. */
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /** Constructor vacío obligatorio para JPA. Protected para que nadie más lo use. */
    protected Order() {
    }

    /**
     * Única forma de crear un pedido nuevo: calcula el total y fija el estado inicial.
     */
    public static Order create(String customerId, String product, int quantity, BigDecimal unitPrice) {
        Order order = new Order();
        order.customerId = customerId;
        order.product = product;
        order.quantity = quantity;
        order.unitPrice = unitPrice;
        order.total = unitPrice.multiply(BigDecimal.valueOf(quantity)).setScale(2, RoundingMode.HALF_UP);
        order.status = OrderStatus.CREATED;
        order.createdAt = Instant.now().truncatedTo(ChronoUnit.MILLIS);
        return order;
    }

    // ---- Getters (sin setters: un pedido creado no se modifica desde fuera) ----

    public UUID getId() {
        return id;
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

    public BigDecimal getUnitPrice() {
        return unitPrice;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
