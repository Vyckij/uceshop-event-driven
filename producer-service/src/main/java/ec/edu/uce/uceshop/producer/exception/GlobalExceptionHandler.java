package ec.edu.uce.uceshop.producer.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Convierte las excepciones en respuestas HTTP claras, con el formato estándar
 * ProblemDetail (RFC 9457): {"type", "title", "status", "detail", ...}.
 * Así ningún error llega al cliente como un "500" confuso.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    /** 400: el JSON llegó pero no cumple las reglas de CreateOrderRequest. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(error -> errors.putIfAbsent(error.getField(), error.getDefaultMessage()));

        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, "La solicitud tiene datos inválidos");
        problem.setTitle("Datos inválidos");
        problem.setProperty("errors", errors);
        return problem;
    }

    /** 404: el pedido consultado no existe. */
    @ExceptionHandler(OrderNotFoundException.class)
    public ProblemDetail handleNotFound(OrderNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Pedido no encontrado");
        return problem;
    }

    /** 503: Kafka no confirmó el evento; el pedido se deshizo (rollback). */
    @ExceptionHandler(EventPublishingException.class)
    public ProblemDetail handlePublishing(EventPublishingException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.SERVICE_UNAVAILABLE,
                "No se pudo publicar el evento en Kafka. El pedido no fue registrado; intente nuevamente.");
        problem.setTitle("Servicio de mensajería no disponible");
        return problem;
    }
}
