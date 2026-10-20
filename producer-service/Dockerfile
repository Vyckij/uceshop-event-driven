# =====================================================================
# consumer-service · Dockerfile multi-etapa
#   Etapa 1 (build):   compila el .jar con Maven + JDK 21
#   Etapa 2 (runtime): imagen pequeña con solo JRE 21 + el .jar
# =====================================================================

# ---------- Etapa 1: compilar ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# 1) Solo el pom.xml: si las dependencias no cambian, Docker reutiliza esta capa
COPY pom.xml .
RUN mvn -B --no-transfer-progress dependency:go-offline

# 2) El código fuente y la compilación (sin tests)
COPY src ./src
RUN mvn -B --no-transfer-progress package -DskipTests

# ---------- Etapa 2: ejecutar ----------
FROM eclipse-temurin:21-jre-alpine

# Usuario sin privilegios (requisito "no-root")
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app

WORKDIR /app
COPY --from=build --chown=app:app /workspace/target/*.jar app.jar

USER app

EXPOSE 8081

# La JVM puede usar hasta el 75 % de la memoria asignada al contenedor
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

# Docker pregunta cada 15 s si la aplicación está viva
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=10 \
  CMD wget -qO- http://localhost:8081/actuator/health/liveness > /dev/null || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]