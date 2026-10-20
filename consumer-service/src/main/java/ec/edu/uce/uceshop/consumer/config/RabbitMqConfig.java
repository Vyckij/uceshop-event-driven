package ec.edu.uce.uceshop.consumer.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.DirectExchange;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Topología de RabbitMQ: 1 exchange, 2 colas y 2 bindings.
 *
 * <pre>
 *                      orders.exchange (direct)
 *          routing key "orders.processed"   routing key "orders.failed"
 *                     │                               │
 *                     ▼                               ▼
 *           orders.notifications                 orders.dlq
 * </pre>
 *
 * Spring (a través de RabbitAdmin) crea estos elementos en RabbitMQ
 * automáticamente si no existen. Si ya existen, no hace nada.
 */
@Configuration
public class RabbitMqConfig {

    private static final Logger log = LoggerFactory.getLogger(RabbitMqConfig.class);

    @Value("${app.rabbitmq.exchange}")
    private String exchangeName;

    @Value("${app.rabbitmq.queues.notifications}")
    private String notificationsQueueName;

    @Value("${app.rabbitmq.queues.dlq}")
    private String deadLetterQueueName;

    @Value("${app.rabbitmq.routing-keys.notifications}")
    private String notificationsRoutingKey;

    @Value("${app.rabbitmq.routing-keys.dlq}")
    private String deadLetterRoutingKey;

    // ---------------- EXCHANGE ----------------

    /** durable = true: sobrevive a reinicios de RabbitMQ. autoDelete = false: no se borra solo. */
    @Bean
    public DirectExchange ordersExchange() {
        return new DirectExchange(exchangeName, true, false);
    }

    // ---------------- COLAS ----------------

    /** Cola de notificaciones: pedidos procesados con éxito. Durable = sobrevive a reinicios. */
    @Bean
    public Queue notificationsQueue() {
        return QueueBuilder.durable(notificationsQueueName).build();
    }

    /** Dead Letter Queue: eventos que no se pudieron procesar, para revisión manual. */
    @Bean
    public Queue deadLetterQueue() {
        return QueueBuilder.durable(deadLetterQueueName).build();
    }

    // ---------------- BINDINGS (reglas de enrutamiento) ----------------

    /** "Lo que llegue al exchange con routing key orders.processed → cola orders.notifications" */
    @Bean
    public Binding notificationsBinding() {
        return BindingBuilder.bind(notificationsQueue())
                .to(ordersExchange())
                .with(notificationsRoutingKey);
    }

    /** "Lo que llegue al exchange con routing key orders.failed → cola orders.dlq" */
    @Bean
    public Binding deadLetterBinding() {
        return BindingBuilder.bind(deadLetterQueue())
                .to(ordersExchange())
                .with(deadLetterRoutingKey);
    }

    // ---------------- FORMATO DE LOS MENSAJES ----------------

    /**
     * Los mensajes viajan como JSON legible (en lugar del formato binario de Java).
     * Usa el ObjectMapper de Spring Boot para que las fechas salgan como texto ISO-8601.
     */
    @Bean
    public MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }

    // ---------------- CREACIÓN AL ARRANCAR ----------------

    /**
     * Spring crea el exchange, las colas y los bindings la PRIMERA vez que se conecta
     * a RabbitMQ. Esta conexión de prueba al arrancar hace que aparezcan de inmediato
     * en la consola web, sin esperar al primer mensaje.
     */
    @Bean
    public ApplicationRunner declareRabbitTopology(ConnectionFactory connectionFactory) {
        return args -> {
            try {
                connectionFactory.createConnection().close();
                log.info("RabbitMQ listo: exchange '{}', colas '{}' y '{}' declaradas",
                        exchangeName, notificationsQueueName, deadLetterQueueName);
            } catch (Exception e) {
                log.warn("RabbitMQ no disponible al arrancar; la topología se creará al reconectar: {}",
                        e.getMessage());
            }
        };
    }
}
