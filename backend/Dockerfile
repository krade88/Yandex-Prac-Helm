# ---------- STAGE 1: build ----------
FROM maven:3.9.6-eclipse-temurin-17 AS builder

ARG VERSION
WORKDIR /usr/src/app

COPY pom.xml .
COPY src ./src

RUN mvn package -Dversion.application=${VERSION} -DskipTests


# ---------- STAGE 2: runtime ----------
FROM eclipse-temurin:17-jdk-alpine

ARG VERSION
WORKDIR /app

RUN addgroup --system jaruser \
    && adduser -S -s /bin/false -G jaruser jaruser -D -H \
    && apk add --no-cache dumb-init curl \
    && mkdir -p /logs/reports \
    && chown -R jaruser:jaruser /logs

COPY --chown=jaruser:jaruser \
     --from=builder /usr/src/app/target/sausage-store-${VERSION}.jar \
     ./sausage-store.jar

EXPOSE 8080

USER jaruser

ENTRYPOINT ["dumb-init", "java", "-jar", "-Dmyserver.bindPort=8080", "sausage-store.jar"]