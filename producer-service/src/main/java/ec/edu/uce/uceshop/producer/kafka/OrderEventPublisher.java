package ec.edu.uce.uceshop.producer.kafka;

import ec.edu.uce.uceshop.producer.event.OrderCreatedEvent;
import ec.edu.uce.uceshop.producer.exception.EventPublishingException;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

/**
 * Publica eventos OrderCreated en Kafka y ESPERA la confirmación del broker.
 * <p>
 * Si Kafka no confirma a tiempo, lanza EventPublishingException para que
 * OrderService deshaga (rollback) el INSERT del pedido.
 */
@Component
public class OrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(OrderEventPublisher.class);

    private final KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate;
    private final String topic;
    private final long sendTimeoutSeconds;

    // Métricas propias. En Prometheus aparecen como:
    //   uceshop_orders_events_published_total y uceshop_orders_events_failed_total
    private final Counter publishedCounter;
    private final Counter failedCounter;

    public OrderEventPublisher(
            KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate,
            @Value("${app.kafka.topics.orders.name}") String topic,
            @Value("${app.kafka.send-timeout-seconds}") long sendTimeoutSeconds,
            MeterRegistry meterRegistry) {

        this.kafkaTemplate = kafkaTemplate;
        this.topic = topic;
        this.sendTimeoutSeconds = sendTimeoutSeconds;
        this.publishedCounter = Counter.builder("uceshop.orders.events.published")
                .description("Eventos OrderCreated confirmados por Kafka")
                .register(meterRegistry);
        this.failedCounter = Counter.builder("uceshop.orders.events.failed")
                .description("Eventos OrderCreated que no se pudieron publicar")
                .register(meterRegistry);
    }

    public void publish(OrderCreatedEvent event) {
        // La key decide la partición: el mismo orderId siempre va a la misma partición
        String key = event.orderId().toString();

        try {
            // send() es asíncrono; .get() espera la confirmación con un tiempo máximo
            SendResult<String, OrderCreatedEvent> result =
                    kafkaTemplate.send(topic, key, event).get(sendTimeoutSeconds, TimeUnit.SECONDS);

            RecordMetadata metadata = result.getRecordMetadata();
            publishedCounter.increment();
            log.info("OrderCreated publicado: orderId={}, topic={}, partition={}, offset={}",
                    key, metadata.topic(), metadata.partition(), metadata.offset());

        } catch (InterruptedException e) {
            // Buena práctica: restaurar la marca de interrupción del hilo
            Thread.currentThread().interrupt();
            failedCounter.increment();
            throw new EventPublishingException(event.orderId(), e);

        } catch (Exception e) {
            failedCounter.increment();
            log.error("No se pudo publicar OrderCreated para orderId={}", key, e);
            throw new EventPublishingException(event.orderId(), e);
        }
    }
}
