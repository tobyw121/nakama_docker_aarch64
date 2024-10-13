FROM debian:bullseye-slim

# Installiere notwendige Pakete
RUN apt-get update && \
    apt-get install -y wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Lade Nakama herunter und entpacke es direkt in das /usr/local/bin Verzeichnis
RUN wget -O - https://github.com/heroiclabs/nakama/releases/download/v3.23.0/nakama-3.23.0-linux-arm64.tar.gz | tar -xzvf - -C /usr/local/bin/ nakama

# Setze Arbeitsverzeichnis
WORKDIR /app

# Definiere den Einstiegspunkt
ENTRYPOINT ["nakama"]
