package ec.edu.uce.uceshop.producer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Punto de entrada del producer-service.
 * <p>
 * {@code @SpringBootApplication} activa la configuración automática y busca
 * componentes (@RestController, @Service, @Component...) en este paquete y sus subpaquetes.
 */
@SpringBootApplication
public class ProducerServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProducerServiceApplication.class, args);
    }
}
