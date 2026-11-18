# Build :   docker compose build
# Démarrer : docker compose up -d
# Logs :    docker compose logs -f
#
# Enshrouded ne fournit AUCUN binaire de serveur Linux : le serveur dédié est un
# exécutable Windows (enshrouded_server.exe, App ID 2278520). On le fait donc
# tourner via Wine + Xvfb, comme le serveur No One Survived de ce homelab.
FROM cm2network/steamcmd:root

# lib32gcc-s1 / lib32stdc++6 sont déjà dans l'image de base : on n'installe que
# ce qui manque pour Wine 64 bits + un serveur X virtuel (headless).
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    gosu \
    wine \
    wine32 \
    wine64 \
    winbind \
    xvfb \
    xauth \
    cabextract \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# winetricks n'est plus empaqueté pour Debian trixie : on récupère le script
# officiel (utilisé seulement en secours, à la création du prefix Wine).
RUN curl -fsSL -o /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks

ENV SERVER_DIR="/home/steam/enshrouded_server"
ENV SAVE_DIR="/home/steam/enshrouded_saves"

COPY --chown=steam:steam start_server.sh /home/steam/start_server.sh
RUN chmod +x /home/steam/start_server.sh

WORKDIR /home/steam

# Depuis le Content Update #2, Enshrouded n'utilise QU'UN port (queryPort),
# fixé côté conteneur à sa valeur officielle par défaut (voir QUERY_PORT dans
# docker-compose.yml) : c'est "ports:" dans docker-compose.yml qui publie ce
# port fixe sur le port externe variable ${jeux1}.
EXPOSE 15637/udp

ENTRYPOINT ["/home/steam/start_server.sh"]
