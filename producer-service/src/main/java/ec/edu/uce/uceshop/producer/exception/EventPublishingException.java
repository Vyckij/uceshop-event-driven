package ec.edu.uce.uceshop.producer.exception;

import java.util.UUID;

/**
 * Se lanza cuando Kafka no confirma la publicación de un evento.
 * Al ser RuntimeException, provoca el rollback de la transacción en OrderService.
 */
public class EventPublishingException extends RuntimeException {

    public EventPublishingException(UUID orderId, Throwable cause) {
        super("No se pudo publicar el evento OrderCreated del pedido " + orderId, cause);
    }
}
