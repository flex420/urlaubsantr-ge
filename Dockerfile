# syntax=docker/dockerfile:1.7

ARG BUILDER_IMAGE=eclipse-temurin:21-jdk
ARG RUNTIME_IMAGE=eclipse-temurin:21-jre

FROM ${BUILDER_IMAGE} AS builder

WORKDIR /workspace

# Warm up Maven dependency cache
COPY app/urlaubsverwaltung/.mvn/ .mvn/
COPY app/urlaubsverwaltung/mvnw mvnw
COPY app/urlaubsverwaltung/pom.xml pom.xml
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -DskipTests -DskipITs dependency:go-offline

# Copy sources and build the Spring Boot fat jar
COPY app/urlaubsverwaltung/. ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -DskipTests -DskipITs package

FROM ${RUNTIME_IMAGE} AS runtime

# Install runtime dependencies needed for health checks
RUN apt-get update \
    && apt-get install --no-install-recommends --yes curl \
    && rm -rf /var/lib/apt/lists/*

ENV APP_HOME=/opt/uv \
    TZ=UTC \
    JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75 -XX:MinRAMPercentage=25 -XX:InitialRAMPercentage=10 -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -Djava.security.egd=file:/dev/urandom"
ENV SPRING_PROFILES_ACTIVE=default
ENV SERVER_PORT=8080

WORKDIR ${APP_HOME}

RUN groupadd --system uv \
    && useradd --system --create-home --gid uv uv

COPY --from=builder /workspace/target/*.jar app.jar
COPY config/ ./config/

USER uv:uv

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=5 \
  CMD curl --fail http://127.0.0.1:${SERVER_PORT}/actuator/health/readiness || exit 1

ENTRYPOINT ["java","-jar","app.jar"]