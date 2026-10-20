package ec.edu.uce.uceshop.consumer.messaging;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.kafka.support.serializer.DeserializationException;

import java.nio.charset.StandardCharsets;
import java.time.Instant;

/**
 * Mensaje que se publica en la Dead Letter Queue (orders.dlq).
 * <p>
 * Guarda TODO lo necesario para que una persona entienda qué falló y pueda
 * reprocesarlo: de dónde salió en Kafka, el contenido original y el error.
 */
public record FailedOrderMessage(
        String sourceTopic,
        int sourcePartition,
        long sourceOffset,
        String key,
        Object originalPayload,
        String errorType,
        String errorMessage,
        String failedBy,
        Instant failedAt
) {

    private static final String SERVICE_NAME = "consumer-service";

    /** Construye el mensaje a partir del registro de Kafka que falló y su excepción. */
    public static FailedOrderMessage from(ConsumerRecord<?, ?> record, Exception exception) {
        Throwable rootCause = NestedExceptionUtils.getMostSpecificCause(exception);

        return new FailedOrderMessage(
                record.topic(),
                record.partition(),
                record.offset(),
                record.key() != null ? record.key().toString() : null,
                originalPayload(record, exception),
                rootCause.getClass().getSimpleName(),
                rootCause.getMessage(),
                SERVICE_NAME,
                Instant.now()
        );
    }

    /**
     * Si el JSON se pudo leer, devuelve el evento. Si NO se pudo leer (JSON roto),
     * el evento llega como null; en ese caso se recuperan los bytes originales
     * guardados por ErrorHandlingDeserializer y se devuelven como texto.
     */
    private static Object originalPayload(ConsumerRecord<?, ?> record, Exception exception) {
        if (record.value() != null) {
            return record.value();
        }
        Throwable current = exception;
        while (current != null) {
            if (current instanceof DeserializationException deserializationException
                    && deserializationException.getData() != null) {
                return new String(deserializationException.getData(), StandardCharsets.UTF_8);
            }
            current = (current.getCause() == current) ? null : current.getCause();
        }
        return null;
    }
}
