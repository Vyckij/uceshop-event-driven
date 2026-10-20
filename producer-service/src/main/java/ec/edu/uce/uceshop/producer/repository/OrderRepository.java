package ec.edu.uce.uceshop.producer.repository;

import ec.edu.uce.uceshop.producer.model.Order;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

/**
 * Repositorio de pedidos. No hace falta escribir SQL ni implementar nada:
 * Spring Data genera en tiempo de ejecución save(), findById(), findAll(), delete(), etc.
 * <p>
 * JpaRepository&lt;Order, UUID&gt; = entidad Order con clave primaria de tipo UUID.
 */
public interface OrderRepository extends JpaRepository<Order, UUID> {
}
