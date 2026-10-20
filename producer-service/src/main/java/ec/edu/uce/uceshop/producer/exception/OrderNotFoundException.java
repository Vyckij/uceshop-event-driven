package ec.edu.uce.uceshop.producer.exception;

import java.util.UUID;

/**
 * Se lanza cuando se consulta un pedido que no existe en producerdb.
 */
public class OrderNotFoundException extends RuntimeException {

    public OrderNotFoundException(UUID orderId) {
        super("No existe un pedido con id " + orderId);
    }
}
