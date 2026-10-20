package ec.edu.uce.uceshop.producer.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

/**
 * Declara el tópico "orders".
 * <p>
 * Al arrancar, Spring Boot revisa si el tópico existe en Kafka:
 * si no existe, lo crea con 3 particiones; si ya existe, no hace nada.
 */
@Configuration
public class KafkaTopicConfig {

    @Bean
    public NewTopic ordersTopic(
            @Value("${app.kafka.topics.orders.name}") String name,
            @Value("${app.kafka.topics.orders.partitions}") int partitions,
            @Value("${app.kafka.topics.orders.replicas}") int replicas) {

        return TopicBuilder.name(name)
                .partitions(partitions)
                .replicas(replicas)
                .build();
    }
}
