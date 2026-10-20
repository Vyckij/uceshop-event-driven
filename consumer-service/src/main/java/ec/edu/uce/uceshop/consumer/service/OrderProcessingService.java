package ec.edu.uce.uceshop.consumer.service;

import ec.edu.uce.uceshop.consumer.dto.ProcessedOrderResponse;
import ec.edu.uce.uceshop.consumer.event.OrderCreatedEvent;
import ec.edu.uce.uceshop.consumer.exception.InvalidOrderEventException;
import ec.edu.uce.uceshop.consumer.model.ProcessedOrder;
import ec.edu.uce.uceshop.consumer.repository.ProcessedOrderRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Lógica de negocio del consumer: validar el evento, evitar duplicados y guardarlo.
 */
@Service
public class OrderProcessingService {

    private static final Logger log = LoggerFactory.getLogger(OrderProcessingService.class);

    private final ProcessedOrderRepository repository;

    // Métricas propias. En Prometheus:
    //   uceshop_orders_events_processed_total y uceshop_orders_events_duplicated_total
    private final Counter processedCounter;
    private final Counter duplicatedCounter;

    public OrderProcessingService(ProcessedOrderRepository repository, MeterRegistry meterRegistry) {
        this.repository = repository;
        this.processedCounter = Counter.builder("uceshop.orders.events.processed")
                .description("Eventos OrderCreated procesados y guardados en consumerdb")
                .register(meterRegistry);
        this.duplicatedCounter = Counter.builder("uceshop.orders.events.duplicated")
                .description("Eventos repetidos que se ignoraron (idempotencia)")
                .register(meterRegistry);
    }

    /**
     * Procesa un evento de forma IDEMPOTENTE: si llega dos veces, se guarda una sola vez.
     * <p>
     * Doble protección:
     * <ol>
     *   <li>Java pregunta antes si el eventId ya existe y, si existe, lo ignora.</li>
     *   <li>La restricción UNIQUE de la base rechaza cualquier duplicado que se escape
     *       (por ejemplo, si dos instancias lo procesan al mismo tiempo). En ese caso
     *       el error provoca un reintento, y en el reintento el paso 1 lo detecta.</li>
     * </ol>
     */
    @Transactional
    public void process(OrderCreatedEvent event, int partition, long offset) {
        validate(event);

        if (repository.existsByEventId(event.eventId())) {
            duplicatedCounter.increment();
            log.warn("Evento duplicado ignorado: eventId={}, orderId={}, partition={}, offset={}",
                    event.eventId(), event.orderId(), partition, offset);
            return;
        }

        ProcessedOrder saved = repository.saveAndFlush(ProcessedOrder.from(event, partition, offset));
        processedCounter.increment();
        log.info("Pedido procesado: orderId={}, eventId={}, partition={}, offset={}, id={}",
                saved.getOrderId(), saved.getEventId(), partition, offset, saved.getId());
    }

    /** Los 50 pedidos procesados más recientes (para GET /processed-orders). */
    @Transactional(readOnly = true)
    public List<ProcessedOrderResponse> findLatest() {
        return repository.findTop50ByOrderByProcessedAtDesc().stream()
                .map(ProcessedOrderResponse::from)
                .toList();
    }

    /** Rechaza eventos vacíos, incompletos o de un tipo que no conocemos. */
    private void validate(OrderCreatedEvent event) {
        if (event == null) {
            throw new InvalidOrderEventException("Mensaje vacío");
        }
        if (!OrderCreatedEvent.TYPE.equals(event.eventType())) {
            throw new InvalidOrderEventException("Tipo de evento desconocido: " + event.eventType());
        }
        if (event.eventId() == null || event.orderId() == null || event.customerId() == null
                || event.product() == null || event.quantity() == null || event.total() == null) {
            throw new InvalidOrderEventException("Evento incompleto: " + event);
        }
    }
}
