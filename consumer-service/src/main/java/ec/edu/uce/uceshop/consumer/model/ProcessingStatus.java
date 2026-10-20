package ec.edu.uce.uceshop.consumer.model;

/**
 * Resultado del procesamiento de un evento.
 * Por ahora solo PROCESSED; en la Fase 4 los rechazados irán a la DLQ de RabbitMQ.
 */
public enum ProcessingStatus {
    PROCESSED
}
