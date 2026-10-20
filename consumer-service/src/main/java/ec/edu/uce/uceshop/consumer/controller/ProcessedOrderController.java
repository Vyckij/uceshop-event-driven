package ec.edu.uce.uceshop.consumer.controller;

import ec.edu.uce.uceshop.consumer.dto.ProcessedOrderResponse;
import ec.edu.uce.uceshop.consumer.service.OrderProcessingService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Endpoint de solo lectura para VERIFICAR qué se procesó.
 * <p>
 * El consumer no recibe pedidos por HTTP (los recibe por Kafka); este GET existe
 * como evidencia, sobre todo en AWS, donde RDS no es accesible desde tu PC.
 */
@RestController
@RequestMapping("/processed-orders")
public class ProcessedOrderController {

    private final OrderProcessingService processingService;

    public ProcessedOrderController(OrderProcessingService processingService) {
        this.processingService = processingService;
    }

    /** GET /processed-orders: los 50 más recientes, con su partición y offset. */
    @GetMapping
    public List<ProcessedOrderResponse> latest() {
        return processingService.findLatest();
    }
}
