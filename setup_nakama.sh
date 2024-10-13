#!/bin/bash

# Erstelle die Dockerfile
cat << EOF > Dockerfile
FROM debian:bullseye-slim

# Installiere notwendige Pakete
RUN apt-get update && \\
    apt-get install -y wget ca-certificates && \\
    rm -rf /var/lib/apt/lists/*

# Lade Nakama herunter und entpacke es direkt in das /usr/local/bin Verzeichnis
RUN wget -O - https://github.com/heroiclabs/nakama/releases/download/v3.23.0/nakama-3.23.0-linux-arm64.tar.gz | tar -xzvf - -C /usr/local/bin/ nakama

# Setze Arbeitsverzeichnis
WORKDIR /app

# Definiere den Einstiegspunkt
ENTRYPOINT ["nakama"]
EOF

# Erstelle die docker-compose-cockroachdb.yml
cat << EOF > docker-compose-cockroachdb.yml
version: '3'

services:
  cockroachdb:
    image: cockroachdb/cockroach:latest-v23.1
    command: start-single-node --insecure --store=attrs=ssd,path=/var/lib/cockroach/
    restart: "no"
    volumes:
      - data:/var/lib/cockroach
    expose:
      - "8080"
      - "26257"
    ports:
      - "26257:26257"
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health?ready=1"]
      interval: 3s
      timeout: 3s
      retries: 5

  nakama:
    build:
      context: .
      dockerfile: Dockerfile
    entrypoint:
      - "/bin/sh"
      - "-ecx"
      - >
          /usr/local/bin/nakama migrate up --database.address root@cockroachdb:26257 --config /app/config/nakama.yml &&
          exec /usr/local/bin/nakama --name nakama1 --database.address root@cockroachdb:26257 --logger.level DEBUG --session.token_expiry_sec 7200 --metrics.prometheus_port 9100 --config /app/config/nakama.yml
    restart: "no"
    links:
      - "cockroachdb:db"
    depends_on:
      cockroachdb:
        condition: service_healthy
      prometheus:
        condition: service_started
    volumes:
      - ./:/nakama/data
      - ./config:/app/config
    expose:
      - "7349"
      - "7350"
      - "7351"
      - "9100"
    ports:
      - "7349:7349"
      - "7350:7350"
      - "7351:7351"
    healthcheck:
      test: ["CMD", "/nakama/nakama", "healthcheck"]
      interval: 10s
      timeout: 5s
      retries: 5

  prometheus:
    image: prom/prometheus
    entrypoint: /bin/sh -c
    command: |
      'sh -s <<EOF
        cat > ./prometheus.yml <<EON
      global:
        scrape_interval:     15s
        evaluation_interval: 15s
      scrape_configs:
        - job_name: prometheus
          static_configs:
          - targets: ['localhost:9090']
        - job_name: nakama
          metrics_path: /
          static_configs:
          - targets: ['nakama:9100']
      EON
      prometheus --config.file=./prometheus.yml
      EOF'
    ports:
      - '9090:9090'

volumes:
  data:
EOF

# Erstelle das config Verzeichnis und die nakama.yml
mkdir -p config
cat << EOF > config/nakama.yml
database:
  address: "root@cockroachdb:26257"
EOF

echo "Dockerfile, docker-compose-cockroachdb.yml und config/nakama.yml wurden erstellt."

# Baue das Image und starte die Container
docker-compose -f docker-compose-cockroachdb.yml up -d

echo "Nakama wird im Docker auf aarch64 ausgeführt."