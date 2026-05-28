#!/bin/bash

set -euo pipefail

# ======================================================================
# SinusBot Multi-Instance Installer / Remover
# ======================================================================

# ------------------ Configuration (common) --------------------------
REQUIRED_SINUSBOT_ARCHIVE="sinusbot.current.tar.bz2"
REQUIRED_TS3_RUN="TeamSpeak3-Client-linux_amd64-3.5.6.run"
INSTALL_BASE="/opt"
START_PORT=8089
TS3_CLIENT_DIR_NAME="TeamSpeak3-Client-linux_amd64"

# ------------------ Colors (optional) -----------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ------------------ 0. Main menu -----------------------------------
main_menu() {
    echo ""
    echo "=============================================="
    echo "  SinusBot Multi-Instance Manager"
    echo "=============================================="
    echo "  1) Full install (system packages + bot)"
    echo "  2) Install bot only (skip system packages)"
    echo "  3) Remove an existing bot"
    echo "=============================================="
    read -rp "Enter your choice [1-3]: " CHOICE
    case "$CHOICE" in
        1) install_deps; install_bot ;;
        2) install_bot ;;
        3) remove_bot ;;
        *) error "Invalid choice. Exiting." ;;
    esac
}

# ------------------ 1. Install system dependencies ------------------
install_deps() {
    info "Installing required system packages..."
    if ! command -v apt-get &>/dev/null; then
        error "apt-get not found. This option only works on Debian/Ubuntu."
    fi
    apt-get update -q
    apt-get install -y --no-install-recommends \
        libfontconfig libxtst6 screen xvfb libxcursor1 ca-certificates \
        bzip2 psmisc libglib2.0-0 less python3 iproute2 dbus libnss3 \
        libegl1-mesa-dev x11-xkb-utils libasound2t64 libxcomposite-dev \
        libxi6 libpci3 libxslt1.1 libxkbcommon0 libxss1 libxdamage1
    info "System packages installed."
}

# ------------------ 2. Remove an existing bot ----------------------
remove_bot() {
    read -rp "Enter the bot name to remove (e.g., sinusbot3): " BOTNAME
    if [[ -z "$BOTNAME" || "$BOTNAME" =~ [^a-zA-Z0-9_-] ]]; then
        error "Invalid bot name. Use only letters, numbers, hyphens, underscores."
    fi

    SERVICE_FILE="/etc/systemd/system/${BOTNAME}.service"

    # Stop and remove systemd service
    if systemctl is-active --quiet "$BOTNAME" 2>/dev/null; then
        systemctl stop "$BOTNAME"
        info "Service $BOTNAME stopped."
    else
        warn "Service $BOTNAME is not running or doesn't exist."
    fi

    if systemctl is-enabled --quiet "$BOTNAME" 2>/dev/null; then
        systemctl disable "$BOTNAME"
        info "Service $BOTNAME disabled."
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        info "Systemd unit file removed."
    else
        warn "Systemd unit file $SERVICE_FILE not found."
    fi

    # Remove user (with home directory)
    if id "$BOTNAME" &>/dev/null; then
        userdel -r "$BOTNAME" 2>/dev/null && info "User $BOTNAME and home directory removed." || warn "Failed to remove user $BOTNAME."
    else
        warn "User $BOTNAME does not exist."
    fi

    # Safety: remove /opt/botname if still exists
    if [[ -d "$INSTALL_BASE/$BOTNAME" ]]; then
        rm -rf "$INSTALL_BASE/$BOTNAME"
        info "Remaining folder $INSTALL_BASE/$BOTNAME deleted."
    fi

    echo ""
    echo "=============================================="
    echo "  Bot '$BOTNAME' has been removed."
    echo "=============================================="
    exit 0
}

# ------------------ 3. Install bot function ------------------------
install_bot() {
    # Prerequisites for installation
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
    fi

    for f in "$REQUIRED_SINUSBOT_ARCHIVE" "$REQUIRED_TS3_RUN"; do
        [[ -f "$f" ]] || error "Required file '$f' not found in current directory ($PWD)."
    done

    for cmd in tar curl useradd systemctl; do
        command -v "$cmd" >/dev/null 2>&1 || error "'$cmd' is required but not installed."
    done

    # ------------------ User input ------------------------------------
    read -rp "Enter the new bot name (e.g., sinusbot2): " BOTNAME
    if [[ -z "$BOTNAME" || "$BOTNAME" =~ [^a-zA-Z0-9_-] ]]; then
        error "Invalid bot name. Use only letters, numbers, hyphens, underscores."
    fi

    if id "$BOTNAME" &>/dev/null; then
        warn "User '$BOTNAME' already exists. The script will reuse it."
        [[ -d "$INSTALL_BASE/$BOTNAME" ]] && error "Directory '$INSTALL_BASE/$BOTNAME' already exists – remove it or pick another name."
    fi

    BOT_USER="$BOTNAME"
    BOT_GROUP="$BOTNAME"
    BOT_HOME="$INSTALL_BASE/$BOTNAME"
    SINUSBOT_DIR="$BOT_HOME/sinusbot"
    DATA_DIR="$SINUSBOT_DIR/data"
    TS3_PATH="$BOT_HOME/$TS3_CLIENT_DIR_NAME/ts3client_linux_amd64"

    # ------------------ Port selection --------------------------------
    find_free_port() {
        local port="$START_PORT"
        while ss -tlnp | grep -q ":$port\b"; do
            ((port++))
        done
        echo "$port"
    }
    PORT=$(find_free_port)
    info "Selected port: $PORT"

    # ------------------ 0. Firewall (ufw) ------------------------------
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow $PORT >/dev/null 2>&1
            info "Firewall (ufw) active – port $PORT opened."
        else
            info "ufw installed but not active, skipping firewall rule."
        fi
    else
        info "ufw not installed, skipping firewall configuration."
    fi

    # ------------------ 1. Create user & directory ---------------------
    if ! id "$BOT_USER" &>/dev/null; then
        useradd -r -m -d "$BOT_HOME" -s /bin/false "$BOT_USER"
        info "User '$BOT_USER' created."
    fi

    # ------------------ 2. Extract SinusBot archive --------------------
    mkdir -p "$BOT_HOME"
    TEMP_EXTRACT="$BOT_HOME/.extract_tmp"
    rm -rf "$TEMP_EXTRACT"
    mkdir -p "$TEMP_EXTRACT"
    tar -xjf "$REQUIRED_SINUSBOT_ARCHIVE" -C "$TEMP_EXTRACT"

    SINUSBOT_EXEC=""
    if [ -f "$TEMP_EXTRACT/sinusbot" ]; then
        mkdir -p "$SINUSBOT_DIR"
        mv "$TEMP_EXTRACT"/* "$SINUSBOT_DIR"/
        SINUSBOT_EXEC="$SINUSBOT_DIR/sinusbot"
    else
        SUBDIR=$(find "$TEMP_EXTRACT" -maxdepth 2 -name sinusbot -type f 2>/dev/null | head -1)
        if [ -n "$SUBDIR" ]; then
            SINUSBOT_DIR_PARENT=$(dirname "$SUBDIR")
            mkdir -p "$SINUSBOT_DIR"
            mv "$SINUSBOT_DIR_PARENT"/* "$SINUSBOT_DIR"/
            SINUSBOT_EXEC="$SINUSBOT_DIR/sinusbot"
        fi
    fi

    rm -rf "$TEMP_EXTRACT"
    [ ! -f "$SINUSBOT_EXEC" ] && error "Could not locate the 'sinusbot' binary after extraction."
    info "SinusBot archive extracted to $SINUSBOT_DIR."

    # ------------------ 3. Install TeamSpeak3 client -------------------
    mkdir -p "$BOT_HOME/$TS3_CLIENT_DIR_NAME"
    "./$REQUIRED_TS3_RUN" --tar xf -C "$BOT_HOME/$TS3_CLIENT_DIR_NAME"

    EXTRACTED_SUBDIR=$(find "$BOT_HOME/$TS3_CLIENT_DIR_NAME" -maxdepth 1 -type d -name "TeamSpeak3-Client-linux_amd64*" 2>/dev/null | head -1)
    if [ -n "$EXTRACTED_SUBDIR" ] && [ "$EXTRACTED_SUBDIR" != "$BOT_HOME/$TS3_CLIENT_DIR_NAME" ]; then
        mv "$EXTRACTED_SUBDIR"/* "$BOT_HOME/$TS3_CLIENT_DIR_NAME/" 2>/dev/null
        rmdir "$EXTRACTED_SUBDIR" 2>/dev/null
    fi

    [ ! -f "$TS3_PATH" ] && error "TeamSpeak client extraction failed. $TS3_PATH missing."
    info "TeamSpeak client installed (silent extraction)."

    # ------------------ 3.5 Copy SinusBot plugin to TS3 client ----------
    mkdir -p "$BOT_HOME/$TS3_CLIENT_DIR_NAME/plugins"
    PLUGIN_SRC="$SINUSBOT_DIR/plugin/libsoundbot_plugin.so"
    if [ -f "$PLUGIN_SRC" ]; then
        cp "$PLUGIN_SRC" "$BOT_HOME/$TS3_CLIENT_DIR_NAME/plugins/"
        info "SinusBot plugin copied to TS3 client plugins."
    else
        warn "Plugin file not found at $PLUGIN_SRC. Will try to continue anyway."
    fi

    # ------------------ 4. Ownership -----------------------------------
    chown -R "$BOT_USER":"$BOT_GROUP" "$BOT_HOME"
    info "Ownership set to $BOT_USER:$BOT_GROUP."

    # ------------------ 5. Configure config.ini ------------------------
    cat > "$SINUSBOT_DIR/config.ini" <<EOF
TS3Path = "$TS3_PATH"
ListenHost = "0.0.0.0"
DataDir = "$DATA_DIR"
ListenPort = $PORT
LocalPlayback = false
EnableLocalFS = false
MaxBulkOperations = 0
LogLevel = 10
EnableProfiler = false
YoutubeDLPath = ""
EnableDebugConsole = true
EnableInternalCommands = true
AllowStreamPush = false
UploadLimit = 83886080
RunAsUser = 0
RunAsGroup = 0
ExternalFileBase = ""
InstanceActionLimit = 0
UseSSL = false
SSLKeyFile = ""
SSLCertFile = ""
Hostname = ""
HostnameMask = ""
SampleInterval = 0
StartVNC = false
EnableWebStream = false
LogFile = ""
LicenseKey = ""
IsProxied = false
DenyStreamURLs = []
Pragma = 0
UserAgent = ""

[YoutubeDL]
  BufferSize = 0
  MaxDownloadSize = 0
  MaxDownloadRate = 0
  MaxSimultaneousChunkDownloads = 0
  CacheStreamed = false
  TimeoutSingleDownloader = 0
  TimeoutMultiDownloader = 0
  ChunkSize = 0

[TS3]
  AvatarMaxWidth = 0
  AvatarMaxHeight = 0
  AllowGIF = false

[StreamRewrites]

[Scripts]
  Debug = true
  AllowReload = true
  EnableTimer = false
  DisableLegacyEvents = false
  DevMode = true
  ScriptTimeout = 15

[Themes]
  Default = ""

[SpeechRecognition]
  Enable = false

[FFmpeg]
  UserAgent = ""
  WaitTime = 0

[DAV]
  Enable = false

[XServer]
  EnableLocalXServer = true
  LocalXServerAddress = ":1"
  Delay = 0
  Debug = false

[SHMem]
  Enable = false
  Size = 0
  Delay = 0
  Interval = 0

[RadioStations]
  URL = ""
  UpdateInterval = 0

[TTS]
  Enabled = false
EOF
    info "config.ini written with port $PORT."

    # ------------------ 5.1 Set instance limit -------------------------
    read -rp "Enter maximum number of instances (0 = unlimited, default 0): " INSTANCE_LIMIT
    INSTANCE_LIMIT=${INSTANCE_LIMIT:-0}
    if [[ "$INSTANCE_LIMIT" =~ ^[0-9]+$ ]]; then
        sed -i "s/^InstanceActionLimit = .*/InstanceActionLimit = $INSTANCE_LIMIT/" "$SINUSBOT_DIR/config.ini"
        info "Instance limit set to $INSTANCE_LIMIT."
    else
        warn "Invalid input. Keeping default unlimited (0)."
    fi

    # ------------------ 6. Create systemd service ----------------------
    cat > "/etc/systemd/system/$BOTNAME.service" <<EOF
[Unit]
Description=SinusBot $BOTNAME
Wants=network-online.target
After=syslog.target network.target network-online.target

[Service]
User=$BOT_USER
Group=$BOT_GROUP
ExecStart=$SINUSBOT_DIR/sinusbot
WorkingDirectory=$SINUSBOT_DIR
Type=simple
KillSignal=2
SendSIGKILL=yes
Environment=QT_XCB_GL_INTEGRATION=none
PrivateTmp=true
LimitNOFILE=512000
LimitNPROC=512000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$BOTNAME" --now
    info "Service '$BOTNAME' started and enabled."

    # ------------------ 7. Wait for web interface ----------------------
    MAX_RETRIES=20
    RETRY=0
    while [[ $RETRY -lt $MAX_RETRIES ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT" | grep -q "200"; then
            break
        fi
        sleep 3
        RETRY=$((RETRY + 1))
    done

    [[ $RETRY -ge $MAX_RETRIES ]] && error "SinusBot web interface did not respond on port $PORT in time."
    info "Web interface is up on port $PORT."

    # ------------------ 8. Copy custom scripts ------------------------
    SCRIPTS_SOURCE="./scripts"
    if [ -d "$SCRIPTS_SOURCE" ]; then
        if [ "$(ls -A "$SCRIPTS_SOURCE" 2>/dev/null)" ]; then
            mkdir -p "$SINUSBOT_DIR/scripts"
            cp -r "$SCRIPTS_SOURCE"/* "$SINUSBOT_DIR/scripts/"
            chown -R "$BOT_USER":"$BOT_GROUP" "$SINUSBOT_DIR/scripts"
            info "Custom scripts from '$SCRIPTS_SOURCE' copied to SinusBot scripts folder."
        else
            warn "Scripts folder '$SCRIPTS_SOURCE' is empty, skipping."
        fi
    else
        warn "Scripts folder '$SCRIPTS_SOURCE' not found, skipping."
    fi

    # ------------------ 8.5 Block TeamSpeak blacklist domains ----------
    info "Adding TeamSpeak blacklist domains to /etc/hosts (if missing)..."
    HOSTS_FILE="/etc/hosts"
    DOMAINS_TO_BLOCK=(
      weblist.teamspeak.com
      abuse.teamspeak.com
      teamspeak.org
      www.teamspeak.org
      accounting.teamspeak.com
      blacklist.teamspeak.com
      ipcheck.teamspeak.com
      blacklist2.teamspeak.com
      greylist.teamspeak.com
    )

    for domain in "${DOMAINS_TO_BLOCK[@]}"; do
        if ! grep -q "$domain" "$HOSTS_FILE"; then
            echo "127.0.0.1 $domain" >> "$HOSTS_FILE"
            info "Added 127.0.0.1 $domain"
        else
            info "$domain already present, skipping."
        fi
    done
    info "Hosts file blocking completed."

    # ------------------ 8.6 Retrieve admin password ------------------
    info "Retrieving admin password..."

    get_password_from_log() {
        journalctl -u "$BOTNAME" --no-pager -b 2>/dev/null | \
            grep -oP "account 'admin' and password '\K[^']+" || true
    }

    ADMIN_PW=""
    sleep 2
    ADMIN_PW=$(get_password_from_log)

    if [[ -n "$ADMIN_PW" ]]; then
        info "Original admin password found in logs."
    else
        warn "Could not find password in logs"
    fi

    # ------------------ 9. Done ----------------------------------------
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "=============================================="
    echo "  New bot installation complete!"
    echo "=============================================="
    echo "  Service name   : $BOTNAME"
    echo "  Web interface  : http://$SERVER_IP:$PORT"
    echo "  Default login  : admin / $ADMIN_PW"
    echo "  Instance limit : $INSTANCE_LIMIT (set in config.ini)"
    echo "  Data folder    : $DATA_DIR"
    echo "  systemctl commands: systemctl {start|stop|restart|status} $BOTNAME"
    echo "=============================================="
}

# ------------------ Kick-off ---------------------------------------
main_menu
