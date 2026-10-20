package ec.edu.uce.uceshop.producer.controller;

import ec.edu.uce.uceshop.producer.dto.CreateOrderRequest;
import ec.edu.uce.uceshop.producer.dto.OrderResponse;
import ec.edu.uce.uceshop.producer.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * API REST de pedidos. Solo recibe la petición HTTP, la valida y delega en OrderService.
 */
@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    /**
     * POST /orders: crea un pedido y publica el evento OrderCreated.
     * Responde 202 Accepted: "recibido, se procesará de forma asíncrona".
     */
    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        OrderResponse response = orderService.createOrder(request);
        return ResponseEntity.accepted().body(response);
    }

    /**
     * GET /orders/{id}: consulta un pedido guardado en producerdb.
     * Útil para verificar datos (y como evidencia en AWS, donde RDS no es accesible desde tu PC).
     */
    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable("id") UUID id) {
        return orderService.getOrder(id);
    }
}
