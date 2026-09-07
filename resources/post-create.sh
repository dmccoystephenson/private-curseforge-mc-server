#!/bin/bash
set -euo pipefail

SERVER_DIR="/mcserver"

# Function: Log a message with the [SERVER-SETUP] prefix
log() {
    local message="$1"
    echo "[SERVER-SETUP] $message"
}

# Function: Validate required environment variables
validate_environment() {
    local warnings=false
    
    if [ -z "$MODPACK_URL" ] || [ "$MODPACK_URL" = "YOUR_MODPACK_URL_HERE" ]; then
        log "No modpack URL specified. Will use default ${MOD_LOADER:-forge} server for Minecraft ${MINECRAFT_VERSION:-1.21.9}"
    fi
    
    if [ "$OPERATOR_UUID" = "YOUR_UUID_HERE" ] || [ -z "$OPERATOR_UUID" ]; then
        log "WARNING: OPERATOR_UUID is not set properly. Consider setting it to your actual UUID from https://mcuuid.net/"
        log "Server will continue with default operator configuration."
        warnings=true
    fi
    
    if [ "$OPERATOR_NAME" = "YOUR_USERNAME_HERE" ] || [ -z "$OPERATOR_NAME" ]; then
        log "WARNING: OPERATOR_NAME is not set properly. Consider setting it to your actual Minecraft username."
        log "Server will continue with default operator configuration."
        warnings=true
    fi
    
    if [ "$warnings" = false ]; then
        log "Environment validation passed."
    else
        log "Server starting with configuration warnings - please check your .env file."
    fi
}

# Function: Download and extract modpack
download_modpack() {
    log "Downloading CurseForge modpack..."
    
    # Create a temporary directory for the download
    local temp_dir="/tmp/modpack-download"
    mkdir -p "$temp_dir"
    
    # Download the modpack
    log "Downloading from: $MODPACK_URL"
    wget -O "$temp_dir/modpack.zip" "$MODPACK_URL" || {
        log "ERROR: Failed to download modpack from $MODPACK_URL"
        exit 1
    }
    
    # Extract the modpack
    log "Extracting modpack..."
    unzip -q "$temp_dir/modpack.zip" -d "$temp_dir/modpack" || {
        log "ERROR: Failed to extract modpack"
        exit 1
    }
    
    # Find the server files (CurseForge packs usually have overrides or a server pack)
    # Look for common patterns
    if [ -d "$temp_dir/modpack/overrides" ]; then
        log "Found overrides directory, copying to server..."
        cp -r "$temp_dir/modpack/overrides/"* "$SERVER_DIR/" 2>/dev/null || true
    fi
    
    if [ -d "$temp_dir/modpack/server" ]; then
        log "Found server directory, copying to server..."
        cp -r "$temp_dir/modpack/server/"* "$SERVER_DIR/" 2>/dev/null || true
    fi
    
    # Copy mods directory if it exists
    if [ -d "$temp_dir/modpack/mods" ]; then
        log "Found mods directory, copying to server..."
        mkdir -p "$SERVER_DIR/mods"
        cp -r "$temp_dir/modpack/mods/"* "$SERVER_DIR/mods/" 2>/dev/null || true
    fi
    
    # Copy config directory if it exists
    if [ -d "$temp_dir/modpack/config" ]; then
        log "Found config directory, copying to server..."
        mkdir -p "$SERVER_DIR/config"
        cp -r "$temp_dir/modpack/config/"* "$SERVER_DIR/config/" 2>/dev/null || true
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    log "Modpack downloaded and extracted successfully"
}

# Function: Download default mod loader (Forge or Fabric)
download_default_modloader() {
    local minecraft_version="${MINECRAFT_VERSION:-1.21.9}"
    local mod_loader="${MOD_LOADER:-forge}"
    
    log "Setting up default $mod_loader server for Minecraft $minecraft_version..."
    
    mkdir -p "$SERVER_DIR/mods"
    mkdir -p "$SERVER_DIR/config"
    
    if [ "$mod_loader" = "forge" ]; then
        # Download Forge installer
        log "Downloading Forge installer for Minecraft $minecraft_version..."
        local forge_url="https://maven.minecraftforge.net/net/minecraftforge/forge/${minecraft_version}/forge-${minecraft_version}-installer.jar"
        
        # Try to download the latest Forge installer
        # Note: This is a simplified approach. In production, you'd want to query the Forge API
        # For specific versions, we use known working Forge builds
        if [ "$minecraft_version" = "1.21.9" ]; then
            forge_url="https://maven.minecraftforge.net/net/minecraftforge/forge/1.21.9-54.0.25/forge-1.21.9-54.0.25-installer.jar"
        elif [ "$minecraft_version" = "1.21.1" ]; then
            forge_url="https://maven.minecraftforge.net/net/minecraftforge/forge/1.21.1-52.0.29/forge-1.21.1-52.0.29-installer.jar"
        elif [ "$minecraft_version" = "1.20.1" ]; then
            forge_url="https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.3.0/forge-1.20.1-47.3.0-installer.jar"
        fi
        
        wget -O "$SERVER_DIR/forge-installer.jar" "$forge_url" || {
            log "ERROR: Failed to download Forge installer"
            log "Please check that Forge is available for Minecraft $minecraft_version"
            exit 1
        }
        
        log "Forge installer downloaded successfully"
    elif [ "$mod_loader" = "fabric" ]; then
        # Download Fabric installer
        log "Downloading Fabric installer for Minecraft $minecraft_version..."
        local fabric_installer_url="https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
        
        wget -O "$SERVER_DIR/fabric-installer.jar" "$fabric_installer_url" || {
            log "ERROR: Failed to download Fabric installer"
            exit 1
        }
        
        # Run Fabric installer directly
        cd "$SERVER_DIR"
        java -jar fabric-installer.jar server -mcversion "$minecraft_version" -downloadMinecraft || {
            log "ERROR: Failed to install Fabric"
            exit 1
        }
        
        log "Fabric server installed successfully"
    else
        log "ERROR: Unknown mod loader: $mod_loader (must be 'forge' or 'fabric')"
        exit 1
    fi
}

# Function: Setup Forge/Fabric server
setup_modded_server() {
    log "Setting up modded server..."
    
    # Look for an installer or server JAR
    local installer_jar=""
    local server_jar=""
    
    # Find installer JAR (forge-installer or fabric-installer)
    if ls "$SERVER_DIR"/forge-*-installer.jar >/dev/null 2>&1; then
        # shellcheck disable=SC2012
        installer_jar=$(ls "$SERVER_DIR"/forge-*-installer.jar | head -1)
        log "Found Forge installer: $installer_jar"
    elif ls "$SERVER_DIR"/forge-installer.jar >/dev/null 2>&1; then
        installer_jar="$SERVER_DIR/forge-installer.jar"
        log "Found Forge installer: $installer_jar"
    elif ls "$SERVER_DIR"/fabric-installer-*.jar >/dev/null 2>&1; then
        # shellcheck disable=SC2012
        installer_jar=$(ls "$SERVER_DIR"/fabric-installer-*.jar | head -1)
        log "Found Fabric installer: $installer_jar"
    elif ls "$SERVER_DIR"/fabric-installer.jar >/dev/null 2>&1; then
        installer_jar="$SERVER_DIR/fabric-installer.jar"
        log "Found Fabric installer: $installer_jar"
    fi
    
    # If installer found, run it
    if [ -n "$installer_jar" ]; then
        log "Running installer..."
        cd "$SERVER_DIR"
        java -jar "$(basename "$installer_jar")" --installServer || {
            log "ERROR: Failed to run installer"
            exit 1
        }
        log "Installer completed successfully"
    fi
    
    # Find the server JAR after installation
    if ls "$SERVER_DIR"/forge-*.jar >/dev/null 2>&1 && ! ls "$SERVER_DIR"/forge-*-installer.jar >/dev/null 2>&1; then
        # shellcheck disable=SC2010
        server_jar=$(ls "$SERVER_DIR"/forge-*.jar | grep -v installer | head -1)
        log "Found Forge server JAR: $server_jar"
    elif ls "$SERVER_DIR"/fabric-server-*.jar >/dev/null 2>&1; then
        # shellcheck disable=SC2012
        server_jar=$(ls "$SERVER_DIR"/fabric-server-*.jar | head -1)
        log "Found Fabric server JAR: $server_jar"
    elif ls "$SERVER_DIR"/fabric-server-launch.jar >/dev/null 2>&1; then
        server_jar="$SERVER_DIR/fabric-server-launch.jar"
        log "Found Fabric server JAR: $server_jar"
    elif ls "$SERVER_DIR"/server.jar >/dev/null 2>&1; then
        server_jar="$SERVER_DIR/server.jar"
        log "Found server.jar"
    fi
    
    if [ -z "$server_jar" ]; then
        log "ERROR: Could not find server JAR file after setup"
        log "Please ensure your modpack includes a server distribution or installer"
        exit 1
    fi
    
    echo "$server_jar"
}

# Function: Setup server
setup_server() {
    if [ -z "$(ls -A "$SERVER_DIR")" ] || [ "$OVERWRITE_EXISTING_SERVER" = "true" ]; then
        log "Setting up new server..."
        rm -rf "${SERVER_DIR:?}"/*
        
        # Check if modpack URL is provided
        if [ -n "$MODPACK_URL" ] && [ "$MODPACK_URL" != "YOUR_MODPACK_URL_HERE" ]; then
            # Download and extract modpack
            download_modpack
        else
            # Download default mod loader
            download_default_modloader
        fi
        
        # Setup modded server (Forge/Fabric)
        SERVER_JAR=$(setup_modded_server)
        
        mkdir -p "$SERVER_DIR"/plugins 2>/dev/null || true
    else
        log "Server is already set up."
        
        # Find existing server JAR
        if ls "$SERVER_DIR"/forge-*.jar >/dev/null 2>&1 && ! ls "$SERVER_DIR"/forge-*-installer.jar >/dev/null 2>&1; then
            # shellcheck disable=SC2010
            SERVER_JAR=$(ls "$SERVER_DIR"/forge-*.jar | grep -v installer | head -1)
        elif ls "$SERVER_DIR"/fabric-server-*.jar >/dev/null 2>&1; then
            # shellcheck disable=SC2012
            SERVER_JAR=$(ls "$SERVER_DIR"/fabric-server-*.jar | head -1)
        elif ls "$SERVER_DIR"/fabric-server-launch.jar >/dev/null 2>&1; then
            SERVER_JAR="$SERVER_DIR/fabric-server-launch.jar"
        elif ls "$SERVER_DIR"/server.jar >/dev/null 2>&1; then
            SERVER_JAR="$SERVER_DIR/server.jar"
        else
            log "ERROR: Could not find server JAR file"
            exit 1
        fi
        log "Using server JAR: $SERVER_JAR"
    fi
}

# Function: Setup ops.json file
setup_ops_file() {
    # Only create ops.json if we have valid operator information
    if [ "$OPERATOR_UUID" != "YOUR_UUID_HERE" ] && [ -n "$OPERATOR_UUID" ] && [ "$OPERATOR_NAME" != "YOUR_USERNAME_HERE" ] && [ -n "$OPERATOR_NAME" ]; then
        log "Creating ops.json file with operator: ${OPERATOR_NAME}"
        cat <<EOF > "$SERVER_DIR"/ops.json
[
  {
    "uuid": "${OPERATOR_UUID}",
    "name": "${OPERATOR_NAME}",
    "level": ${OPERATOR_LEVEL},
    "bypassesPlayerLimit": false
  }
]
EOF
    else
        log "Skipping ops.json creation - operator information not properly configured."
        log "You can add operators manually using the 'op <username>' command in the server console."
    fi
}

# Function: Accept EULA
accept_eula() {
    log "Accepting Minecraft EULA..."
    echo "eula=true" > "$SERVER_DIR"/eula.txt
}

# Function: Update server properties
update_server_properties() {
    local props_file="$SERVER_DIR/server.properties"
    
    if [ -f "$props_file" ]; then
        log "Updating server.properties with environment settings..."
        
        # Update settings using sed
        sed -i "s/^motd=.*/motd=${SERVER_MOTD}/" "$props_file" || echo "motd=${SERVER_MOTD}" >> "$props_file"
        sed -i "s/^max-players=.*/max-players=${MAX_PLAYERS}/" "$props_file" || echo "max-players=${MAX_PLAYERS}" >> "$props_file"
        sed -i "s/^difficulty=.*/difficulty=${DIFFICULTY}/" "$props_file" || echo "difficulty=${DIFFICULTY}" >> "$props_file"
        sed -i "s/^gamemode=.*/gamemode=${GAMEMODE}/" "$props_file" || echo "gamemode=${GAMEMODE}" >> "$props_file"
        sed -i "s/^pvp=.*/pvp=${PVP_ENABLED}/" "$props_file" || echo "pvp=${PVP_ENABLED}" >> "$props_file"
        sed -i "s/^online-mode=.*/online-mode=${ONLINE_MODE}/" "$props_file" || echo "online-mode=${ONLINE_MODE}" >> "$props_file"
    else
        log "No existing server.properties found, creating new one..."
        create_server_properties
    fi
}

# Function: Create server properties
create_server_properties() {
    log "Creating server.properties file..."
    cat <<EOF > "$SERVER_DIR"/server.properties
#Minecraft server properties
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=${GAMEMODE}
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=world
motd=${SERVER_MOTD}
query.port=25565
pvp=${PVP_ENABLED}
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=${DIFFICULTY}
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=${MAX_PLAYERS}
online-mode=${ONLINE_MODE}
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
debug=false
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
EOF
}

# Function: Start server
start_server() {
    log "Starting server with graceful shutdown wrapper..."
    /resources/minecraft-wrapper.sh \
        "$(basename "$SERVER_JAR")" \
        "$SERVER_DIR" \
        "${JAVA_OPTS:--Xmx4G -Xms2G}"
}

# Main Process
log "Running server setup script..."
validate_environment
setup_server
setup_ops_file
accept_eula
update_server_properties

# Start Server
start_server
