package ec.edu.uce.uceshop.producer.service;

import ec.edu.uce.uceshop.producer.dto.CreateOrderRequest;
import ec.edu.uce.uceshop.producer.dto.OrderResponse;
import ec.edu.uce.uceshop.producer.event.OrderCreatedEvent;
import ec.edu.uce.uceshop.producer.exception.OrderNotFoundException;
import ec.edu.uce.uceshop.producer.kafka.OrderEventPublisher;
import ec.edu.uce.uceshop.producer.model.Order;
import ec.edu.uce.uceshop.producer.repository.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Lógica de negocio de los pedidos: guardar en producerdb y publicar el evento en Kafka.
 */
@Service
public class OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    private final OrderRepository orderRepository;
    private final OrderEventPublisher orderEventPublisher;

    // Inyección por constructor: Spring entrega automáticamente las dependencias
    public OrderService(OrderRepository orderRepository, OrderEventPublisher orderEventPublisher) {
        this.orderRepository = orderRepository;
        this.orderEventPublisher = orderEventPublisher;
    }

    /**
     * Crea un pedido. Todo ocurre dentro de UNA transacción de base de datos:
     * <ol>
     *   <li>INSERT del pedido (saveAndFlush lo ejecuta de inmediato).</li>
     *   <li>Publicación del evento en Kafka, esperando confirmación.</li>
     *   <li>Si Kafka falla, la excepción provoca ROLLBACK: el pedido NO queda guardado.</li>
     *   <li>Si todo sale bien, COMMIT al terminar el método.</li>
     * </ol>
     */
    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        Order order = Order.create(
                request.customerId().trim(),
                request.product().trim(),
                request.quantity(),
                request.unitPrice()
        );

        Order saved = orderRepository.saveAndFlush(order);
        orderEventPublisher.publish(OrderCreatedEvent.from(saved));

        log.info("Pedido creado: orderId={}, customerId={}, total={}",
                saved.getId(), saved.getCustomerId(), saved.getTotal());
        return OrderResponse.from(saved);
    }

    /** Busca un pedido por su id; si no existe lanza OrderNotFoundException (404). */
    @Transactional(readOnly = true)
    public OrderResponse getOrder(UUID orderId) {
        return orderRepository.findById(orderId)
                .map(OrderResponse::from)
                .orElseThrow(() -> new OrderNotFoundException(orderId));
    }
}
