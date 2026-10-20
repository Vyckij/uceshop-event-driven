package ec.edu.uce.uceshop.producer.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * Datos que el cliente envía en el cuerpo (JSON) de POST /orders.
 * <p>
 * Es un "record": una clase inmutable que Java completa sola con constructor,
 * getters (customerId(), product()...), equals, hashCode y toString.
 * Las anotaciones definen las reglas de validación; si una falla, se responde 400.
 */
public record CreateOrderRequest(

        @NotBlank(message = "customerId es obligatorio")
        @Size(max = 50, message = "customerId admite máximo 50 caracteres")
        String customerId,

        @NotBlank(message = "product es obligatorio")
        @Size(max = 120, message = "product admite máximo 120 caracteres")
        String product,

        @NotNull(message = "quantity es obligatorio")
        @Positive(message = "quantity debe ser mayor que 0")
        @Max(value = 10000, message = "quantity admite máximo 10000")
        Integer quantity,

        @NotNull(message = "unitPrice es obligatorio")
        @DecimalMin(value = "0.01", message = "unitPrice debe ser al menos 0.01")
        @Digits(integer = 8, fraction = 2, message = "unitPrice admite hasta 8 enteros y 2 decimales")
        BigDecimal unitPrice
) {
}
