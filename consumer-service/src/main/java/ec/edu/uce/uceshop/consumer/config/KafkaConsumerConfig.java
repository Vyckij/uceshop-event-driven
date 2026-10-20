package ec.edu.uce.uceshop.consumer.config;

import ec.edu.uce.uceshop.consumer.exception.InvalidOrderEventException;
import ec.edu.uce.uceshop.consumer.exception.OrderRejectedException;
import ec.edu.uce.uceshop.consumer.messaging.FailedOrderMessage;
import ec.edu.uce.uceshop.consumer.messaging.RabbitMessagePublisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

/**
 * Qué hacer cuando procesar un mensaje de Kafka falla.
 * <ul>
 *   <li>Error temporal (base de datos o RabbitMQ caídos un momento):
 *       3 reintentos, esperando 1 segundo entre cada uno.</li>
 *   <li>Evento inválido, pedido rechazado o JSON mal formado: sin reintentos.</li>
 *   <li>Cuando ya no quedan reintentos: el evento se envía a la DLQ de RabbitMQ
 *       y el consumer continúa con el siguiente mensaje.</li>
 * </ul>
 * Si ni siquiera se puede enviar a la DLQ (RabbitMQ apagado), el mensaje NO se pierde:
 * Kafka lo vuelve a entregar más tarde.
 */
@Configuration
public class KafkaConsumerConfig {

    private static final Logger log = LoggerFactory.getLogger(KafkaConsumerConfig.class);

    @Bean
    public DefaultErrorHandler kafkaErrorHandler(
            @Value("${app.kafka.retry.attempts}") long attempts,
            @Value("${app.kafka.retry.interval-ms}") long intervalMs,
            RabbitMessagePublisher rabbitPublisher) {

        DefaultErrorHandler errorHandler = new DefaultErrorHandler(
                // "Recoverer": se ejecuta cuando ya no quedan reintentos → DLQ
                (record, exception) -> {
                    log.error("Procesamiento fallido, enviando a la DLQ: partition={}, offset={}, causa={}",
                            record.partition(), record.offset(),
                            NestedExceptionUtils.getMostSpecificCause(exception).getMessage());
                    rabbitPublisher.publishToDeadLetterQueue(FailedOrderMessage.from(record, exception));
                },
                new FixedBackOff(intervalMs, attempts));

        // Estos errores no se arreglan reintentando: van directo a la DLQ
        errorHandler.addNotRetryableExceptions(
                InvalidOrderEventException.class,
                OrderRejectedException.class);
        return errorHandler;
    }
}
