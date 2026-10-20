package ec.edu.uce.uceshop.consumer.exception;

/**
 * El evento llegó incompleto o con un tipo desconocido.
 * <p>
 * Reintentar no lo arreglaría (el mensaje seguirá igual de incompleto),
 * por eso KafkaConsumerConfig la marca como "no reintentable".
 */
public class InvalidOrderEventException extends RuntimeException {

    public InvalidOrderEventException(String message) {
        super(message);
    }
}
