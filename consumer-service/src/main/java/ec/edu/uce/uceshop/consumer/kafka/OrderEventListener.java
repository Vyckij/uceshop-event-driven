package ec.edu.uce.uceshop.consumer.kafka;

import ec.edu.uce.uceshop.consumer.event.OrderCreatedEvent;
import ec.edu.uce.uceshop.consumer.service.OrderProcessingService;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

/**
 * Escucha el tópico "orders". Spring llama a onOrderCreated() por cada mensaje que llega.
 * <p>
 * Con concurrency = 3 hay 3 hilos ejecutando este método en paralelo,
 * cada uno atendiendo una partición distinta.
 */
@Component
public class OrderEventListener {

    private static final Logger log = LoggerFactory.getLogger(OrderEventListener.class);

    private final OrderProcessingService processingService;

    public OrderEventListener(OrderProcessingService processingService) {
        this.processingService = processingService;
    }

    /**
     * ConsumerRecord trae el mensaje completo: key, value (el evento ya convertido
     * desde JSON), partición y offset.
     * <p>
     * Si este método termina sin error, Spring confirma el offset (commit).
     * Si lanza una excepción, entra en juego el manejador de errores de KafkaConsumerConfig.
     */
    @KafkaListener(topics = "${app.kafka.topics.orders.name}")
    public void onOrderCreated(ConsumerRecord<String, OrderCreatedEvent> record) {
        log.info("Evento recibido: key={}, partition={}, offset={}",
                record.key(), record.partition(), record.offset());

        processingService.process(record.value(), record.partition(), record.offset());
    }
}
