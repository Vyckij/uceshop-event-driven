package ec.edu.uce.uceshop.producer.model;

/**
 * Estados posibles de un pedido en el producer-service.
 * Por ahora solo existe CREATED; en el futuro podrían agregarse otros (CANCELLED, etc.).
 */
public enum OrderStatus {
    CREATED
}
