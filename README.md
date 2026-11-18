# Enshrouded — Dedicated Server (Docker)

🇬🇧 [English](#english) | 🇫🇷 [Français](#français)

---

## English

Docker container to host an **Enshrouded** dedicated server (SteamCMD App ID `2278520`).

Enshrouded ships **no Linux server binary**: the dedicated server is a Windows executable
(`enshrouded_server.exe`). This image runs it with **Wine** on top of a virtual X server
(**Xvfb**), which is required even though the server is headless.

- Docker Hub image: [`ludix0/enshrouded`](https://hub.docker.com/r/ludix0/enshrouded)
- Port used: **one single UDP port** (`queryPort`, `15637` by default). The separate
  `gamePort` was removed from Enshrouded in Content Update #2 — do not open a second port.
- Player cap imposed by the game: **16 slots**.
- The whole `enshrouded_server.json` is generated at every container start from the
  environment variables below. Editing that file inside the volume has no effect.

### Requirements

- Docker and Docker Compose v2
- ~10 GB of free disk space, and **8 GB of RAM** available for the server (Wine included)
- One UDP port forwarded to the host on your router/firewall

### Method 1 — Quick install from Docker Hub (recommended)

```yaml
services:
  enshrouded:
    image: ludix0/enshrouded:latest
    container_name: enshrouded
    restart: unless-stopped
    stop_grace_period: 90s
    volumes:
      - ./volumes/enshrouded/filesServer:/home/steam/enshrouded_server
      - ./volumes/enshrouded/saves:/home/steam/enshrouded_saves
      - ./volumes/enshrouded/wineprefix:/home/steam/.wine
      - ./volumes/steamcmd:/home/steam/steamcmd
    environment:
      - TZ=Europe/Paris
      - PUID=1000
      - PGID=1000
      - UPDATE_ON_START=true
      - SERVER_NAME=My Enshrouded Server
      - QUERY_PORT=15637
      - SLOT_COUNT=16
      - ADMIN_PASSWORD=change-me-admin
      - FRIEND_PASSWORD=change-me-friend
      - GUEST_PASSWORD=change-me-guest
      - GAME_SETTINGS_PRESET=Default
    ports:
      - "15637:15637/udp"
```

```bash
docker compose up -d
docker compose logs -f
```

The first start downloads the server, builds the Wine prefix and installs the Visual C++
runtime — allow **10 to 20 minutes** before the server shows up in the game.

> The three group passwords **must be different from each other**: the password a player
> types at connection time is what decides which group (Admin / Friend / Guest) they join.

### Method 2 — Build from source (GitHub)

```bash
git clone https://github.com/Ludix0/enshrouded.git enshrouded
cd enshrouded
# Provide the variables used by docker-compose.yml (${jeux1}, ${password},
# ${adminPassword}, ${maxPlayers}, ${TZ}, ${PUID}, ${PGID}) in a .env file
docker compose build
docker compose up -d
```

### Environment variables

**System**

| Variable | Required | Description |
|---|---|---|
| `TZ` | no | Container time zone (e.g. `Europe/Paris`) |
| `PUID` / `PGID` | no | UID/GID owning the files (default `1000`) |
| `UPDATE_ON_START` | no | `true` = run SteamCMD update at every start |
| `STEAM_USER` / `STEAM_PASSWORD` | no | Leave empty: the server downloads anonymously |

**Server**

| Variable | Default | Description |
|---|---|---|
| `SERVER_NAME` | `Ludix_Enshrouded_FR` | Name shown in the server list |
| `SERVER_PASSWORD` | *(empty)* | Legacy `password` field, no longer used by the game |
| `SERVER_IP` | `0.0.0.0` | Bind address — do not change |
| `QUERY_PORT` | `15637` | **The** UDP port of the server |
| `SLOT_COUNT` | `16` | Player slots, hard cap 16 |
| `ENABLE_VOICE_CHAT` | `false` | Voice chat |
| `VOICE_CHAT_MODE` | `Proximity` | `Proximity` or `Global` |
| `ENABLE_TEXT_CHAT` | `true` | Text chat |

**Player groups** — `ADMIN_*`, `FRIEND_*`, `GUEST_*`

| Variable | Description |
|---|---|
| `<GROUP>_PASSWORD` | Group password (must be unique per group) |
| `<GROUP>_CAN_KICK_BAN` | Allowed to kick/ban |
| `<GROUP>_CAN_ACCESS_INVENTORIES` | Allowed to open others' chests |
| `<GROUP>_CAN_EDIT_BASE` | Allowed to build/destroy in a base |
| `<GROUP>_CAN_EXTEND_BASE` | Allowed to extend base boundaries |
| `<GROUP>_RESERVED_SLOTS` | Slots reserved for that group |

**Difficulty**

| Variable | Default | Accepted values |
|---|---|---|
| `GAME_SETTINGS_PRESET` | `Default` | `Default`, `Relaxed`, `Hard`, `Survival`, `Custom` |

> ⚠️ Every fine-grained setting below is read **only** when
> `GAME_SETTINGS_PRESET=Custom`. With any other preset the game loads its own values and
> silently ignores them.

| Variable | Default | Accepted values / range |
|---|---|---|
| `PLAYER_HEALTH_FACTOR` | `1` | 0.25 – 4 |
| `PLAYER_MANA_FACTOR` | `1` | 0.25 – 4 |
| `PLAYER_STAMINA_FACTOR` | `1` | 0.25 – 4 |
| `PLAYER_BODY_HEAT_FACTOR` | `1` | `0.5`, `1`, `1.5`, `2` |
| `PLAYER_DIVING_TIME_FACTOR` | `1` | multiplier |
| `ENABLE_DURABILITY` | `true` | `true` / `false` |
| `ENABLE_STARVING_DEBUFF` | `false` | `true` / `false` |
| `FOOD_BUFF_DURATION_FACTOR` | `1` | multiplier |
| `FROM_HUNGER_TO_STARVING_MINUTES` | `10` | 5 – 20 (minutes) |
| `SHROUD_TIME_FACTOR` | `1` | multiplier |
| `TOMBSTONE_MODE` | `AddBackpackMaterials` | `AddBackpackMaterials`, `Everything`, `NoTombstone` |
| `ENABLE_GLIDER_TURBULENCES` | `true` | `true` / `false` |
| `WEATHER_FREQUENCY` | `Normal` | `Disabled`, `Rare`, `Normal`, `Often` |
| `FISHING_DIFFICULTY` | `Normal` | `VeryEasy`, `Easy`, `Normal`, `Hard`, `VeryHard` |
| `MINING_DAMAGE_FACTOR` | `1` | multiplier |
| `PLANT_GROWTH_SPEED_FACTOR` | `1` | multiplier |
| `RESOURCE_DROP_STACK_AMOUNT_FACTOR` | `1` | multiplier |
| `FACTORY_PRODUCTION_SPEED_FACTOR` | `1` | multiplier |
| `DAY_TIME_DURATION_MINUTES` | `30` | 2 – 60 (minutes) |
| `NIGHT_TIME_DURATION_MINUTES` | `12` | 2 – 60 (minutes) |
| `PERK_UPGRADE_RECYCLING_FACTOR` | `0.5` | 0 – 1 |
| `PERK_COST_FACTOR` | `1` | multiplier |
| `EXPERIENCE_COMBAT_FACTOR` | `1` | multiplier |
| `EXPERIENCE_MINING_FACTOR` | `1` | multiplier |
| `EXPERIENCE_EXPLORATION_QUESTS_FACTOR` | `1` | multiplier |
| `RANDOM_SPAWNER_AMOUNT` | `Normal` | `Few`, `Normal`, `Many`, `Extreme` |
| `AGGRO_POOL_AMOUNT` | `Normal` | `Few`, `Normal`, `Many`, `Extreme` |
| `ENEMY_DAMAGE_FACTOR` | `1` | multiplier |
| `ENEMY_HEALTH_FACTOR` | `1` | multiplier |
| `ENEMY_STAMINA_FACTOR` | `1` | multiplier |
| `ENEMY_PERCEPTION_RANGE_FACTOR` | `1` | multiplier |
| `BOSS_DAMAGE_FACTOR` | `1` | multiplier |
| `BOSS_HEALTH_FACTOR` | `1` | multiplier |
| `THREAT_BONUS` | `1` | multiplier |
| `PACIFY_ALL_ENEMIES` | `false` | `true` / `false` |
| `TAMING_STARTLE_REPERCUSSION` | `LoseSomeProgress` | `KeepProgress`, `LoseSomeProgress`, `LoseAllProgress` |
| `CURSE_MODIFIER` | `Normal` | `Easy`, `Normal`, `Hard` |

### Volumes

| Volume | Content |
|---|---|
| `/home/steam/enshrouded_server` | Server binaries installed by SteamCMD (replaceable) |
| `/home/steam/enshrouded_saves` | `savegame/` and `logs/` — **the data to back up** |
| `/home/steam/.wine` | Wine prefix (avoids rebuilding it at every start) |
| `/home/steam/steamcmd` | SteamCMD, shareable with other game servers |

### Ports

| Port | Protocol | Purpose |
|---|---|---|
| `QUERY_PORT` (`15637`) | UDP | Game traffic **and** Steam query — the only port needed |

The host port can differ from the container port (`"<HOST_PORT>:15637/udp"`) — Enshrouded is
joined by direct IP connect, so players simply use whatever host port you give them; Docker's
NAT translation to the fixed container port is fully transparent, no need to keep them equal.

### Troubleshooting

| Symptom | Fix |
|---|---|
| `enshrouded_server.exe` never appears | SteamCMD needs `+@sSteamCmdForcePlatformType windows` (already in the script) — check the SteamCMD output in the logs |
| Server invisible in game | Check the UDP port forwarding, and that host and container ports are identical |
| Custom settings ignored | `GAME_SETTINGS_PRESET` must be exactly `Custom` |
| Container restarting in a loop | Read `docker compose logs -f`, then the game log in `saves/logs/` |

---

## Français

Conteneur Docker pour héberger un serveur dédié **Enshrouded** (App ID SteamCMD `2278520`).

Enshrouded ne fournit **aucun binaire de serveur Linux** : le serveur dédié est un
exécutable Windows (`enshrouded_server.exe`). Cette image le fait tourner avec **Wine**
au-dessus d'un serveur X virtuel (**Xvfb**), indispensable même si le serveur est sans
interface graphique.

- Image Docker Hub : [`ludix0/enshrouded`](https://hub.docker.com/r/ludix0/enshrouded)
- Port utilisé : **un seul port UDP** (`queryPort`, `15637` par défaut). Le `gamePort`
  séparé a été supprimé d'Enshrouded au Content Update #2 — ne pas ouvrir de second port.
- Nombre de joueurs maximum imposé par le jeu : **16**.
- Tout le fichier `enshrouded_server.json` est régénéré à chaque démarrage du conteneur
  à partir des variables d'environnement ci-dessous. Modifier ce fichier dans le volume
  n'a donc aucun effet.

### Prérequis

- Docker et Docker Compose v2
- ~10 Go d'espace disque libre et **8 Go de RAM** disponibles pour le serveur (Wine compris)
- Un port UDP redirigé vers l'hôte sur le routeur/pare-feu

### Méthode 1 — Installation rapide depuis Docker Hub (recommandée)

```yaml
services:
  enshrouded:
    image: ludix0/enshrouded:latest
    container_name: enshrouded
    restart: unless-stopped
    stop_grace_period: 90s
    volumes:
      - ./volumes/enshrouded/filesServer:/home/steam/enshrouded_server
      - ./volumes/enshrouded/saves:/home/steam/enshrouded_saves
      - ./volumes/enshrouded/wineprefix:/home/steam/.wine
      - ./volumes/steamcmd:/home/steam/steamcmd
    environment:
      - TZ=Europe/Paris
      - PUID=1000
      - PGID=1000
      - UPDATE_ON_START=true
      - SERVER_NAME=Mon serveur Enshrouded
      - QUERY_PORT=15637
      - SLOT_COUNT=16
      - ADMIN_PASSWORD=a-changer-admin
      - FRIEND_PASSWORD=a-changer-ami
      - GUEST_PASSWORD=a-changer-invite
      - GAME_SETTINGS_PRESET=Default
    ports:
      - "15637:15637/udp"
```

```bash
docker compose up -d
docker compose logs -f
```

Le premier démarrage télécharge le serveur, construit le prefix Wine et installe le
runtime Visual C++ : compter **10 à 20 minutes** avant que le serveur apparaisse en jeu.

> Les trois mots de passe de groupe **doivent être différents entre eux** : c'est le mot
> de passe saisi par le joueur à la connexion qui détermine son groupe
> (Admin / Friend / Guest).

### Méthode 2 — Build depuis les sources (GitHub)

```bash
git clone https://github.com/Ludix0/enshrouded.git enshrouded
cd enshrouded
# Renseigner dans un fichier .env les variables utilisées par docker-compose.yml
# (${jeux1}, ${password}, ${adminPassword}, ${maxPlayers}, ${TZ}, ${PUID}, ${PGID})
docker compose build
docker compose up -d
```

### Variables d'environnement

**Système**

| Variable | Obligatoire | Description |
|---|---|---|
| `TZ` | non | Fuseau horaire du conteneur (ex. `Europe/Paris`) |
| `PUID` / `PGID` | non | UID/GID propriétaire des fichiers (défaut `1000`) |
| `UPDATE_ON_START` | non | `true` = mise à jour SteamCMD à chaque démarrage |
| `STEAM_USER` / `STEAM_PASSWORD` | non | Laisser vide : téléchargement anonyme |

**Serveur**

| Variable | Défaut | Description |
|---|---|---|
| `SERVER_NAME` | `Ludix_Enshrouded_FR` | Nom affiché dans la liste des serveurs |
| `SERVER_PASSWORD` | *(vide)* | Ancien champ `password`, plus utilisé par le jeu |
| `SERVER_IP` | `0.0.0.0` | Adresse d'écoute — ne pas modifier |
| `QUERY_PORT` | `15637` | **LE** port UDP du serveur |
| `SLOT_COUNT` | `16` | Nombre de places, maximum absolu 16 |
| `ENABLE_VOICE_CHAT` | `false` | Chat vocal |
| `VOICE_CHAT_MODE` | `Proximity` | `Proximity` (proximité) ou `Global` |
| `ENABLE_TEXT_CHAT` | `true` | Chat écrit |

**Groupes de joueurs** — `ADMIN_*`, `FRIEND_*`, `GUEST_*`

| Variable | Description |
|---|---|
| `<GROUPE>_PASSWORD` | Mot de passe du groupe (unique pour chaque groupe) |
| `<GROUPE>_CAN_KICK_BAN` | Droit d'expulser/bannir |
| `<GROUPE>_CAN_ACCESS_INVENTORIES` | Droit d'ouvrir les coffres des autres |
| `<GROUPE>_CAN_EDIT_BASE` | Droit de construire/détruire dans une base |
| `<GROUPE>_CAN_EXTEND_BASE` | Droit d'agrandir les limites d'une base |
| `<GROUPE>_RESERVED_SLOTS` | Places réservées à ce groupe |

**Difficulté**

| Variable | Défaut | Valeurs acceptées |
|---|---|---|
| `GAME_SETTINGS_PRESET` | `Default` | `Default`, `Relaxed`, `Hard`, `Survival`, `Custom` |

> ⚠️ Tous les réglages fins ci-dessous ne sont lus **que** si
> `GAME_SETTINGS_PRESET=Custom`. Avec un autre preset, le jeu charge ses propres valeurs
> et ignore silencieusement les vôtres.

| Variable | Défaut | Valeurs / plage |
|---|---|---|
| `PLAYER_HEALTH_FACTOR` | `1` | 0.25 – 4 (points de vie) |
| `PLAYER_MANA_FACTOR` | `1` | 0.25 – 4 (mana) |
| `PLAYER_STAMINA_FACTOR` | `1` | 0.25 – 4 (endurance) |
| `PLAYER_BODY_HEAT_FACTOR` | `1` | `0.5`, `1`, `1.5`, `2` (résistance au froid) |
| `PLAYER_DIVING_TIME_FACTOR` | `1` | temps d'apnée sous l'eau |
| `ENABLE_DURABILITY` | `true` | `true` / `false` (usure de l'équipement) |
| `ENABLE_STARVING_DEBUFF` | `false` | `true` / `false` (malus de famine) |
| `FOOD_BUFF_DURATION_FACTOR` | `1` | durée des bonus alimentaires |
| `FROM_HUNGER_TO_STARVING_MINUTES` | `10` | 5 – 20 (minutes avant la famine) |
| `SHROUD_TIME_FACTOR` | `1` | temps de survie dans le Voile |
| `TOMBSTONE_MODE` | `AddBackpackMaterials` | `AddBackpackMaterials`, `Everything`, `NoTombstone` |
| `ENABLE_GLIDER_TURBULENCES` | `true` | `true` / `false` (turbulences en deltaplane) |
| `WEATHER_FREQUENCY` | `Normal` | `Disabled`, `Rare`, `Normal`, `Often` |
| `FISHING_DIFFICULTY` | `Normal` | `VeryEasy`, `Easy`, `Normal`, `Hard`, `VeryHard` |
| `MINING_DAMAGE_FACTOR` | `1` | vitesse de minage |
| `PLANT_GROWTH_SPEED_FACTOR` | `1` | vitesse de pousse des cultures |
| `RESOURCE_DROP_STACK_AMOUNT_FACTOR` | `1` | quantité de ressources récoltées |
| `FACTORY_PRODUCTION_SPEED_FACTOR` | `1` | vitesse de production des ateliers |
| `DAY_TIME_DURATION_MINUTES` | `30` | 2 – 60 (durée du jour) |
| `NIGHT_TIME_DURATION_MINUTES` | `12` | 2 – 60 (durée de la nuit) |
| `PERK_UPGRADE_RECYCLING_FACTOR` | `0.5` | 0 – 1 (ressources rendues en désapprenant) |
| `PERK_COST_FACTOR` | `1` | coût des talents |
| `EXPERIENCE_COMBAT_FACTOR` | `1` | XP de combat |
| `EXPERIENCE_MINING_FACTOR` | `1` | XP de minage |
| `EXPERIENCE_EXPLORATION_QUESTS_FACTOR` | `1` | XP d'exploration et de quêtes |
| `RANDOM_SPAWNER_AMOUNT` | `Normal` | `Few`, `Normal`, `Many`, `Extreme` (densité d'ennemis) |
| `AGGRO_POOL_AMOUNT` | `Normal` | `Few`, `Normal`, `Many`, `Extreme` (ennemis attaquant en même temps) |
| `ENEMY_DAMAGE_FACTOR` | `1` | dégâts des ennemis |
| `ENEMY_HEALTH_FACTOR` | `1` | points de vie des ennemis |
| `ENEMY_STAMINA_FACTOR` | `1` | endurance des ennemis |
| `ENEMY_PERCEPTION_RANGE_FACTOR` | `1` | distance de détection |
| `BOSS_DAMAGE_FACTOR` | `1` | dégâts des boss |
| `BOSS_HEALTH_FACTOR` | `1` | points de vie des boss |
| `THREAT_BONUS` | `1` | niveau de menace global |
| `PACIFY_ALL_ENEMIES` | `false` | `true` = ennemis passifs |
| `TAMING_STARTLE_REPERCUSSION` | `LoseSomeProgress` | `KeepProgress`, `LoseSomeProgress`, `LoseAllProgress` |
| `CURSE_MODIFIER` | `Normal` | `Easy`, `Normal`, `Hard` (sévérité de la malédiction) |

### Volumes

| Volume | Contenu |
|---|---|
| `/home/steam/enshrouded_server` | Binaires du serveur installés par SteamCMD (remplaçables) |
| `/home/steam/enshrouded_saves` | `savegame/` et `logs/` — **les données à sauvegarder** |
| `/home/steam/.wine` | Prefix Wine (évite de le reconstruire à chaque démarrage) |
| `/home/steam/steamcmd` | SteamCMD, partageable avec les autres serveurs de jeux |

### Ports

| Port | Protocole | Usage |
|---|---|---|
| `QUERY_PORT` (`15637`) | UDP | Trafic de jeu **et** requête Steam — le seul port nécessaire |

Le port hôte peut différer du port conteneur (`"<PORT_HOTE>:15637/udp"`) — Enshrouded se
rejoint en connexion IP directe, le joueur utilise simplement le port hôte qu'on lui donne ;
la translation NAT de Docker vers le port fixe du conteneur est totalement transparente,
pas besoin qu'ils soient identiques.

### Dépannage

| Symptôme | Solution |
|---|---|
| `enshrouded_server.exe` n'apparaît jamais | SteamCMD a besoin de `+@sSteamCmdForcePlatformType windows` (déjà dans le script) — vérifier sa sortie dans les logs |
| Serveur invisible en jeu | Vérifier la redirection du port UDP, et que les ports hôte et conteneur sont identiques |
| Réglages personnalisés ignorés | `GAME_SETTINGS_PRESET` doit valoir exactement `Custom` |
| Conteneur qui redémarre en boucle | Lire `docker compose logs -f`, puis le log du jeu dans `saves/logs/` |
