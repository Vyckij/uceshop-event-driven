package ec.edu.uce.uceshop.consumer.repository;

import ec.edu.uce.uceshop.consumer.model.ProcessedOrder;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

/**
 * Repositorio de pedidos procesados.
 * <p>
 * Los métodos de abajo son "consultas derivadas": Spring Data lee el NOMBRE
 * del método y genera el SQL automáticamente.
 */
public interface ProcessedOrderRepository extends JpaRepository<ProcessedOrder, Long> {

    /** SELECT ... WHERE event_id = ?  → true si el evento ya fue procesado. */
    boolean existsByEventId(UUID eventId);

    /** Los 50 registros más recientes, ordenados por processed_at descendente. */
    List<ProcessedOrder> findTop50ByOrderByProcessedAtDesc();
}
