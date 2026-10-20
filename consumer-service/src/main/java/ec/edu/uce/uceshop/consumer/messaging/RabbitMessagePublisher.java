package ec.edu.uce.uceshop.consumer.messaging;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Publica mensajes en RabbitMQ.
 * <p>
 * Siempre se envía al EXCHANGE con una ROUTING KEY; nunca directamente a una cola.
 * Los bindings de RabbitMqConfig deciden a qué cola llega cada mensaje.
 */
@Component
public class RabbitMessagePublisher {

    private static final Logger log = LoggerFactory.getLogger(RabbitMessagePublisher.class);

    private final RabbitTemplate rabbitTemplate;
    private final String exchange;
    private final String notificationsRoutingKey;
    private final String deadLetterRoutingKey;

    // Métricas en Prometheus:
    //   uceshop_orders_notifications_published_total
    //   uceshop_orders_events_failed_total   (eventos enviados a la DLQ)
    private final Counter notificationsCounter;
    private final Counter deadLetterCounter;

    public RabbitMessagePublisher(
            RabbitTemplate rabbitTemplate,
            @Value("${app.rabbitmq.exchange}") String exchange,
            @Value("${app.rabbitmq.routing-keys.notifications}") String notificationsRoutingKey,
            @Value("${app.rabbitmq.routing-keys.dlq}") String deadLetterRoutingKey,
            MeterRegistry meterRegistry) {

        this.rabbitTemplate = rabbitTemplate;
        this.exchange = exchange;
        this.notificationsRoutingKey = notificationsRoutingKey;
        this.deadLetterRoutingKey = deadLetterRoutingKey;
        this.notificationsCounter = Counter.builder("uceshop.orders.notifications.published")
                .description("Notificaciones de pedidos procesados enviadas a RabbitMQ")
                .register(meterRegistry);
        this.deadLetterCounter = Counter.builder("uceshop.orders.events.failed")
                .description("Eventos que fallaron y se enviaron a la DLQ de RabbitMQ")
                .register(meterRegistry);
    }

    /** Envía la notificación de un pedido procesado → cola orders.notifications */
    public void publishNotification(OrderNotification notification) {
        rabbitTemplate.convertAndSend(exchange, notificationsRoutingKey, notification);
        notificationsCounter.increment();
        log.info("Notificación publicada en RabbitMQ: orderId={}, routingKey={}",
                notification.orderId(), notificationsRoutingKey);
    }

    /** Envía un evento fallido → cola orders.dlq */
    public void publishToDeadLetterQueue(FailedOrderMessage message) {
        rabbitTemplate.convertAndSend(exchange, deadLetterRoutingKey, message);
        deadLetterCounter.increment();
        log.warn("Evento enviado a la DLQ: partition={}, offset={}, error={}: {}",
                message.sourcePartition(), message.sourceOffset(),
                message.errorType(), message.errorMessage());
    }
}
