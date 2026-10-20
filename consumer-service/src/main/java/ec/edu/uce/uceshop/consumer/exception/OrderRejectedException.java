package ec.edu.uce.uceshop.consumer.exception;

public class OrderRejectedException extends RuntimeException {

    public OrderRejectedException(String message) {
        super(message);
    }
}