#!/bin/bash
set -e

APP_ID=2278520          # Enshrouded Dedicated Server (téléchargeable en anonyme)
SERVER_BIN="enshrouded_server.exe"

# ── 1. Ajustement UID/GID ──────────────────────────────────────────────────
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}

echo "Ajustement de l'utilisateur steam vers UID: $USER_ID et GID: $GROUP_ID..."
groupmod -g "$GROUP_ID" steam
usermod -u "$USER_ID" -g "$GROUP_ID" steam

chown -R steam:steam "${SERVER_DIR}"  2>/dev/null || true
chown -R steam:steam "${SAVE_DIR}"    2>/dev/null || true
chown -R steam:steam /home/steam/.wine 2>/dev/null || true
chown -R steam:steam /home/steam/

# ── 2. Mise à jour via SteamCMD ────────────────────────────────────────────
# Le serveur Enshrouded n'existe qu'en version Windows : il FAUT forcer le type
# de plateforme "windows", sinon SteamCMD ne trouve aucun dépôt à télécharger.
if [ "$UPDATE_ON_START" = "true" ] || [ ! -f "${SERVER_DIR}/${SERVER_BIN}" ]; then
    echo "--- Mise à jour du serveur Enshrouded (SteamCMD App: ${APP_ID}) ---"
    if [ -n "$STEAM_USER" ]; then
        echo "--- Connexion avec le compte Steam: $STEAM_USER ---"
        LOGIN_ARGS=(+login "$STEAM_USER" "$STEAM_PASSWORD")
    else
        LOGIN_ARGS=(+login anonymous)
    fi
    for i in 1 2 3; do
        gosu steam /home/steam/steamcmd/steamcmd.sh \
            +@sSteamCmdForcePlatformType windows \
            +force_install_dir "${SERVER_DIR}" \
            "${LOGIN_ARGS[@]}" \
            +app_update "${APP_ID}" validate \
            +quit && break
        echo "--- Tentative $i échouée, nouvel essai dans 10s ---"
        sleep 10
    done
else
    echo "--- Saut de la mise à jour (UPDATE_ON_START=false) ---"
fi

if [ ! -f "${SERVER_DIR}/${SERVER_BIN}" ]; then
    echo "--- ERREUR : ${SERVER_BIN} absent de ${SERVER_DIR}, le téléchargement a échoué. ---"
    exit 1
fi

# ── 3. Sauvegardes et logs hors du dossier des binaires ────────────────────
# enshrouded_server.json attend des chemins relatifs (le binaire est un .exe :
# les chemins Windows/Wine sont une source d'ennuis). On garde donc "./savegame"
# et "./logs" dans la config, et on les fait pointer par lien symbolique vers le
# volume des sauvegardes — les binaires (réinstallables) restent séparés des
# sauvegardes (précieuses).
mkdir -p "${SAVE_DIR}/savegame" "${SAVE_DIR}/logs"
ln -sfn "${SAVE_DIR}/savegame" "${SERVER_DIR}/savegame"
ln -sfn "${SAVE_DIR}/logs"     "${SERVER_DIR}/logs"
chown -R steam:steam "${SAVE_DIR}" 2>/dev/null || true

# ── 4. Environnement Wine + serveur X virtuel ──────────────────────────────
export HOME=/home/steam
export WINEPREFIX=/home/steam/.wine
export WINEARCH=win64
export WINEDEBUG=-all
export DISPLAY=:99

mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
# restart: unless-stopped relance le MÊME conteneur (même /tmp) : on nettoie les
# verrous laissés par un essai précédent, sinon Xvfb refuse de démarrer.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

Xvfb :99 -screen 0 1024x768x16 > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!

WAIT=0
until [ -e /tmp/.X11-unix/X99 ]; do
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "--- Xvfb s'est arrêté immédiatement, échec du démarrage. Log : ---"
        cat /tmp/xvfb.log 2>/dev/null
        exit 1
    fi
    if [ $WAIT -ge 30 ]; then
        echo "--- Timeout : Xvfb n'a pas créé son socket après 30s. Log : ---"
        cat /tmp/xvfb.log 2>/dev/null
        exit 1
    fi
    echo "--- Attente de Xvfb ---"
    sleep 1
    WAIT=$((WAIT + 1))
done

if [ ! -f "${WINEPREFIX}/system.reg" ]; then
    echo "--- Initialisation du prefix Wine (premier lancement, peut prendre plusieurs minutes) ---"
    gosu steam wineboot --init
    # "gosu steam" est indispensable ici : le prefix appartient à steam, un
    # wineserver lancé en root (le shell du script) échoue avec "is not owned
    # by you" et, avec set -e, fait sortir le script en erreur -> redémarrage
    # inutile du conteneur par restart: unless-stopped.
    gosu steam wineserver -w
    echo "--- Installation des runtimes Visual C++ (winetricks vcrun2022) ---"
    gosu steam winetricks -q vcrun2022 || echo "--- vcrun2022 non installé, on continue (souvent facultatif) ---"
    gosu steam wineserver -w
    chown -R steam:steam /home/steam/.wine 2>/dev/null || true
fi

# ── 5. Génération de enshrouded_server.json ────────────────────────────────
# Le fichier est RÉÉCRIT à chaque démarrage depuis les variables d'environnement
# de docker-compose.yml : c'est docker-compose.yml qui fait référence, pas le
# fichier dans le volume (toute retouche manuelle y sera écrasée).

# Normalise "True"/"TRUE"/"1" -> true pour le JSON (qui n'accepte que minuscules)
bool() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) echo "true" ;;
        *)             echo "false" ;;
    esac
}
# Les durées d'Enshrouded sont en nanosecondes : on les saisit en minutes
# (plus lisible) et on convertit ici. 1 min = 60 000 000 000 ns.
ns_from_min() { echo $(( ${1%%.*} * 60000000000 )); }

CONFIG_FILE="${SERVER_DIR}/enshrouded_server.json"

cat > "${CONFIG_FILE}" <<EOF
{
  "name": "${SERVER_NAME:-Ludix_Enshrouded_FR}",
  "password": "${SERVER_PASSWORD:-}",
  "saveDirectory": "./savegame",
  "logDirectory": "./logs",
  "ip": "${SERVER_IP:-0.0.0.0}",
  "queryPort": ${QUERY_PORT:-15637},
  "slotCount": ${SLOT_COUNT:-16},
  "voiceChatMode": "${VOICE_CHAT_MODE:-Proximity}",
  "enableVoiceChat": $(bool "${ENABLE_VOICE_CHAT:-false}"),
  "enableTextChat": $(bool "${ENABLE_TEXT_CHAT:-true}"),
  "userGroups": [
    {
      "name": "Admin",
      "password": "${ADMIN_PASSWORD:-adminpassword}",
      "canKickBan": $(bool "${ADMIN_CAN_KICK_BAN:-true}"),
      "canAccessInventories": $(bool "${ADMIN_CAN_ACCESS_INVENTORIES:-true}"),
      "canEditBase": $(bool "${ADMIN_CAN_EDIT_BASE:-true}"),
      "canExtendBase": $(bool "${ADMIN_CAN_EXTEND_BASE:-true}"),
      "reservedSlots": ${ADMIN_RESERVED_SLOTS:-1}
    },
    {
      "name": "Friend",
      "password": "${FRIEND_PASSWORD:-friendpassword}",
      "canKickBan": $(bool "${FRIEND_CAN_KICK_BAN:-false}"),
      "canAccessInventories": $(bool "${FRIEND_CAN_ACCESS_INVENTORIES:-true}"),
      "canEditBase": $(bool "${FRIEND_CAN_EDIT_BASE:-true}"),
      "canExtendBase": $(bool "${FRIEND_CAN_EXTEND_BASE:-true}"),
      "reservedSlots": ${FRIEND_RESERVED_SLOTS:-0}
    },
    {
      "name": "Guest",
      "password": "${GUEST_PASSWORD:-guestpassword}",
      "canKickBan": $(bool "${GUEST_CAN_KICK_BAN:-false}"),
      "canAccessInventories": $(bool "${GUEST_CAN_ACCESS_INVENTORIES:-false}"),
      "canEditBase": $(bool "${GUEST_CAN_EDIT_BASE:-false}"),
      "canExtendBase": $(bool "${GUEST_CAN_EXTEND_BASE:-false}"),
      "reservedSlots": ${GUEST_RESERVED_SLOTS:-0}
    }
  ],
  "gameSettingsPreset": "${GAME_SETTINGS_PRESET:-Default}",
  "gameSettings": {
    "playerHealthFactor": ${PLAYER_HEALTH_FACTOR:-1},
    "playerManaFactor": ${PLAYER_MANA_FACTOR:-1},
    "playerStaminaFactor": ${PLAYER_STAMINA_FACTOR:-1},
    "playerBodyHeatFactor": ${PLAYER_BODY_HEAT_FACTOR:-1},
    "playerDivingTimeFactor": ${PLAYER_DIVING_TIME_FACTOR:-1},
    "enableDurability": $(bool "${ENABLE_DURABILITY:-true}"),
    "enableStarvingDebuff": $(bool "${ENABLE_STARVING_DEBUFF:-false}"),
    "foodBuffDurationFactor": ${FOOD_BUFF_DURATION_FACTOR:-1},
    "fromHungerToStarving": $(ns_from_min "${FROM_HUNGER_TO_STARVING_MINUTES:-10}"),
    "shroudTimeFactor": ${SHROUD_TIME_FACTOR:-1},
    "tombstoneMode": "${TOMBSTONE_MODE:-AddBackpackMaterials}",
    "enableGliderTurbulences": $(bool "${ENABLE_GLIDER_TURBULENCES:-true}"),
    "weatherFrequency": "${WEATHER_FREQUENCY:-Normal}",
    "fishingDifficulty": "${FISHING_DIFFICULTY:-Normal}",
    "miningDamageFactor": ${MINING_DAMAGE_FACTOR:-1},
    "plantGrowthSpeedFactor": ${PLANT_GROWTH_SPEED_FACTOR:-1},
    "resourceDropStackAmountFactor": ${RESOURCE_DROP_STACK_AMOUNT_FACTOR:-1},
    "factoryProductionSpeedFactor": ${FACTORY_PRODUCTION_SPEED_FACTOR:-1},
    "perkUpgradeRecyclingFactor": ${PERK_UPGRADE_RECYCLING_FACTOR:-0.5},
    "perkCostFactor": ${PERK_COST_FACTOR:-1},
    "experienceCombatFactor": ${EXPERIENCE_COMBAT_FACTOR:-1},
    "experienceMiningFactor": ${EXPERIENCE_MINING_FACTOR:-1},
    "experienceExplorationQuestsFactor": ${EXPERIENCE_EXPLORATION_QUESTS_FACTOR:-1},
    "randomSpawnerAmount": "${RANDOM_SPAWNER_AMOUNT:-Normal}",
    "aggroPoolAmount": "${AGGRO_POOL_AMOUNT:-Normal}",
    "enemyDamageFactor": ${ENEMY_DAMAGE_FACTOR:-1},
    "enemyHealthFactor": ${ENEMY_HEALTH_FACTOR:-1},
    "enemyStaminaFactor": ${ENEMY_STAMINA_FACTOR:-1},
    "enemyPerceptionRangeFactor": ${ENEMY_PERCEPTION_RANGE_FACTOR:-1},
    "bossDamageFactor": ${BOSS_DAMAGE_FACTOR:-1},
    "bossHealthFactor": ${BOSS_HEALTH_FACTOR:-1},
    "threatBonus": ${THREAT_BONUS:-1},
    "pacifyAllEnemies": $(bool "${PACIFY_ALL_ENEMIES:-false}"),
    "tamingStartleRepercussion": "${TAMING_STARTLE_REPERCUSSION:-LoseSomeProgress}",
    "curseModifier": "${CURSE_MODIFIER:-Normal}",
    "dayTimeDuration": $(ns_from_min "${DAY_TIME_DURATION_MINUTES:-30}"),
    "nightTimeDuration": $(ns_from_min "${NIGHT_TIME_DURATION_MINUTES:-12}")
  }
}
EOF

chown steam:steam "${CONFIG_FILE}"
echo "--- Configuration générée (${CONFIG_FILE}) ---"
cat "${CONFIG_FILE}"

if [ "${GAME_SETTINGS_PRESET:-Default}" != "Custom" ]; then
    echo "--- INFO : GAME_SETTINGS_PRESET=${GAME_SETTINGS_PRESET:-Default} : le bloc gameSettings est IGNORÉ par le jeu. Mettre 'Custom' pour que les réglages fins s'appliquent. ---"
fi

# ── 6. Lancement du serveur ────────────────────────────────────────────────
cd "${SERVER_DIR}"

echo "--- Lancement d'Enshrouded sur le port UDP ${QUERY_PORT:-15637} ---"
exec gosu steam wine "${SERVER_BIN}"
