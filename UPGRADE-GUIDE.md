# CurseForge Modpack Server Upgrade Guide

This guide provides a comprehensive process for upgrading your CurseForge modpack server to a newer version while ensuring data safety and the ability to rollback if needed.

## Table of Contents

- [Before You Begin](#before-you-begin)
- [Upgrade Process](#upgrade-process)
- [Rollback Procedure](#rollback-procedure)
- [Post-Upgrade Verification](#post-upgrade-verification)
- [Troubleshooting](#troubleshooting)

## Before You Begin

### Important Notes

⚠️ **Critical**: Always backup your server data before performing an upgrade. This allows you to restore your server if the upgrade fails or causes issues.

⚠️ **Compatibility**: Check that the new modpack version is compatible with your existing world. Major version changes may break worlds or cause corruption.

⚠️ **Mods**: New modpack versions may add, remove, or update mods. Verify mod compatibility and backup before upgrading.

⚠️ **Downtime**: The upgrade process requires server downtime. Plan the upgrade during a maintenance window and notify your players in advance.

### Prerequisites

- Docker and Docker Compose installed and running
- Access to the server host machine
- Sufficient disk space for backups (at least 2x your current world size)
- The new modpack download URL from CurseForge
- Knowledge of the target modpack version

## Upgrade Process

### Automated Upgrade (Recommended)

For a streamlined upgrade experience, use the automated upgrade script that handles all steps:

```bash
./upgrade.sh
```

The script will:
1. ✅ Stop the server gracefully
2. ✅ Create a timestamped backup automatically
3. ✅ Prompt for the new modpack URL and version
4. ✅ Update the `.env` file
5. ✅ Rebuild the Docker image with the new modpack
6. ✅ Start the server and show initial logs

**Benefits:**
- Single command execution
- Automatic backup management
- Interactive prompts with confirmation
- Progress feedback at each step
- Summary with backup location

**Example usage:**
```bash
./upgrade.sh
# When prompted, enter the new modpack URL
# Enter the new version (e.g., 1.1.0)
# Confirm the upgrade when asked
# Script handles the rest automatically
```

If you prefer manual control or need to understand each step, continue with the manual process below.

---

### Manual Upgrade Process

### Step 1: Stop the Server

First, gracefully stop the Minecraft server to ensure all data is properly saved:

```bash
./down.sh
```

Or using Docker Compose directly:

```bash
docker compose down
```

**Important**: The server includes graceful shutdown handling that automatically saves all data before stopping.

### Step 2: Backup Server Files

Create a backup of all server data from the persistent volume. This is your safety net in case something goes wrong.

#### Option A: Backup to Local Directory (Recommended)

```bash
# Create a backup directory with timestamp
mkdir -p ./backups
BACKUP_DIR="./backups/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Copy server data from the container volume
docker run --rm \
  -v mcserver-curseforge:/mcserver:ro \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  ubuntu \
  tar czf /backup/mcserver-backup.tar.gz -C /mcserver .

echo "Backup created at: $BACKUP_DIR/mcserver-backup.tar.gz"
```

#### Option B: Quick Backup via Docker CP

```bash
# Create backup directory
mkdir -p ./backups/backup-$(date +%Y%m%d-%H%M%S)

# Start a temporary container to access the volume
docker run -d --name mcserver-backup \
  -v mcserver-curseforge:/mcserver:ro \
  ubuntu sleep 300

# Copy the data
docker cp mcserver-backup:/mcserver "./backups/backup-$(date +%Y%m%d-%H%M%S)/"

# Cleanup temporary container
docker rm -f mcserver-backup
```

#### Option C: Using Deposit Box

```bash
# Copy world and important files to deposit box
docker run --rm \
  -v mcserver-curseforge:/mcserver:ro \
  -v "$(pwd)/deposit-box":/deposit-box \
  ubuntu \
  bash -c "cp -r /mcserver/world /deposit-box/ && \
           cp -r /mcserver/mods /deposit-box/ && \
           cp -r /mcserver/config /deposit-box/ && \
           cp /mcserver/ops.json /deposit-box/ 2>/dev/null || true && \
           cp /mcserver/whitelist.json /deposit-box/ 2>/dev/null || true"
```

**Verify your backup** before proceeding:

```bash
# For Option A
ls -lh "$BACKUP_DIR/mcserver-backup.tar.gz"

# For Option B
du -sh "./backups/backup-$(date +%Y%m%d-%H%M%S)/"
```

### Step 3: Get New Modpack Information

Visit CurseForge and find the new version of your modpack:

1. Navigate to your modpack on [CurseForge](https://www.curseforge.com/minecraft/modpacks)
2. Click "Download" for the new version
3. Copy the download URL
4. Note the version number

### Step 4: Update Modpack Configuration

Edit your `.env` file to specify the new modpack:

```bash
# Open .env in your preferred editor
nano .env
# or
vim .env
```

Update the `MODPACK_URL` and `MODPACK_VERSION` variables:

```bash
# Change from (example):
MODPACK_URL=https://www.curseforge.com/minecraft/modpacks/your-modpack/download/1234567
MODPACK_VERSION=1.0.0

# To your new version (example):
MODPACK_URL=https://www.curseforge.com/minecraft/modpacks/your-modpack/download/1234568
MODPACK_VERSION=1.1.0
```

### Step 5: Rebuild Docker Image

Rebuild the Docker image with the new modpack version. This process will:
- Download the new modpack from CurseForge
- Extract and setup the server files
- Take 5-10 minutes depending on modpack size and your connection

```bash
docker compose build --no-cache
```

**Note**: The `--no-cache` flag ensures a clean build without using old cached layers.

### Step 6: Replace Server Files in Persistent Volume

The new modpack needs to replace the old server files. The `post-create.sh` script handles this automatically based on the `OVERWRITE_EXISTING_SERVER` setting.

#### Option A: Preserve Existing World (Recommended)

If you want to keep your existing world and update mods/config:

```bash
# The server will use existing data by default
./up.sh
```

The setup script will:
- Detect existing server files
- Preserve your world data
- Keep custom configurations

**Note**: This may cause issues if the new modpack has incompatible mods or major changes.

#### Option B: Fresh Server Setup with World Migration

If you want to reset everything but migrate your world:

```bash
# First, copy your world to deposit-box
docker run --rm \
  -v mcserver-curseforge:/mcserver:ro \
  -v "$(pwd)/deposit-box":/deposit-box \
  ubuntu \
  cp -r /mcserver/world /deposit-box/

# Enable overwrite to reset server
echo "OVERWRITE_EXISTING_SERVER=true" >> .env

# Start the server (this will reset everything)
./up.sh

# Wait for server to start, then stop it
sleep 30
./down.sh

# Copy world back
docker run --rm \
  -v mcserver-curseforge:/mcserver \
  -v "$(pwd)/deposit-box":/deposit-box \
  ubuntu \
  cp -r /deposit-box/world /mcserver/

# Disable overwrite for future restarts
sed -i 's/OVERWRITE_EXISTING_SERVER=true/OVERWRITE_EXISTING_SERVER=false/' .env

# Start the server again
./up.sh
```

### Step 7: Start and Monitor the Server

Start the server and monitor the logs to ensure successful startup:

```bash
# Start the server
./up.sh

# Monitor server logs in real-time
docker logs -f private-curseforge-mc-server
```

**Look for these indicators of successful startup:**
- `[SERVER-SETUP] Starting server with graceful shutdown wrapper...`
- `Done (X.XXXs)! For help, type "help"`
- All mods loading successfully
- No errors about missing or incompatible mods

Press `Ctrl+C` to stop following the logs (server continues running).

## Rollback Procedure

If the upgrade fails or causes issues, you can restore your server from the backup.

### Step 1: Stop the Server

```bash
./down.sh
```

### Step 2: Remove Current Server Volume

**Warning**: This will delete the current server data. Make sure you have a backup!

```bash
# Remove the volume
docker volume rm mcserver-curseforge
```

### Step 3: Restore from Backup

#### If you used Option A (tar.gz backup):

```bash
# Specify your backup file
BACKUP_FILE="./backups/backup-YYYYMMDD-HHMMSS/mcserver-backup.tar.gz"

# Restore the data
docker run --rm \
  -v mcserver-curseforge:/mcserver \
  -v "$(pwd)/$(dirname $BACKUP_FILE)":/backup \
  ubuntu \
  tar xzf /backup/$(basename $BACKUP_FILE) -C /mcserver
```

#### If you used Option B (directory backup):

```bash
# Specify your backup directory
BACKUP_DIR="./backups/backup-YYYYMMDD-HHMMSS"

# Start a temporary container
docker run -d --name mcserver-restore \
  -v mcserver-curseforge:/mcserver \
  ubuntu sleep 300

# Copy the data back
docker cp "$BACKUP_DIR/mcserver/." mcserver-restore:/mcserver/

# Cleanup
docker rm -f mcserver-restore
```

### Step 4: Revert Configuration

Restore your previous `.env` settings:

```bash
# Edit .env to restore old modpack URL and version
nano .env
```

### Step 5: Rebuild and Restart

```bash
# Rebuild with the old version
docker compose build --no-cache

# Start the server
./up.sh
```

## Post-Upgrade Verification

After upgrading, verify that everything is working correctly:

### 1. Check Server Status

```bash
# Verify the container is running
docker ps | grep private-curseforge-mc-server

# Check server logs
docker logs private-curseforge-mc-server --tail 50
```

### 2. Test Server Connection

- Connect to the server using your Minecraft client with the same modpack
- Verify the server version matches your upgrade target
- Check that all mods are loaded on both client and server

### 3. Verify World Data

- Check that your world loaded correctly
- Verify builds and structures are intact
- Test chunk loading and generation
- Verify modded blocks and items still work

### 4. Check Mods

```bash
# View mod loading from logs
docker logs private-curseforge-mc-server | grep -i "Loading.*mod"
```

Verify that:
- All expected mods are loaded
- No mod errors in the logs
- Mod functionality works in-game
- No missing mod items or blocks

### 5. Test Core Functionality

- Player movement and interaction
- Block breaking and placing
- Inventory management
- Modded items and blocks
- Commands and permissions
- Chat and multiplayer features

### 6. Monitor Performance

```bash
# Check resource usage
docker stats private-curseforge-mc-server

# Watch for errors
docker logs -f private-curseforge-mc-server | grep -i error
```

## Troubleshooting

### Server Fails to Start After Upgrade

**Symptoms**: Container stops immediately or crashes on startup

**Solutions**:
1. Check the logs for specific errors:
   ```bash
   docker logs private-curseforge-mc-server
   ```
2. Common issues:
   - Incompatible world format: Rollback to previous version
   - Missing or incompatible mods: Check mod compatibility
   - Insufficient memory: Increase memory in `post-create.sh`
   - Invalid modpack URL: Verify the download URL

### "Mod Rejection" or "Missing Mods" Error

**Symptoms**: Players cannot connect, mod mismatch errors

**Solutions**:
1. Ensure players have the same modpack version installed
2. Verify all required mods are loaded:
   ```bash
   docker logs private-curseforge-mc-server | grep -i mod
   ```
3. Check for client-side-only mods that shouldn't be on the server

### World Data Missing or Corrupted

**Symptoms**: Empty world, missing builds, or world won't load

**Solutions**:
1. Immediately stop the server:
   ```bash
   ./down.sh
   ```
2. Follow the [Rollback Procedure](#rollback-procedure)
3. Do not start the server until the rollback is complete

### Mods Not Loading

**Symptoms**: Mod features not working, mod errors in logs

**Solutions**:
1. Check mod compatibility with the Minecraft version
2. Verify mods are in `/mcserver/mods` directory:
   ```bash
   docker exec private-curseforge-mc-server ls -la /mcserver/mods/
   ```
3. Check for mod conflicts in logs
4. Ensure Forge/Fabric installed correctly

### Performance Degradation

**Symptoms**: Lag, low TPS (ticks per second), high CPU/memory usage

**Solutions**:
1. Check resource usage:
   ```bash
   docker stats private-curseforge-mc-server
   ```
2. Adjust memory allocation in `resources/post-create.sh`:
   ```bash
   # Default is -Xmx4G -Xms2G
   # Increase to -Xmx6G -Xms3G or higher
   ```
3. Optimize server properties (view-distance, simulation-distance)
4. Check for problematic mods in logs

### Modpack Download Fails

**Symptoms**: Build fails with download errors

**Solutions**:
1. Verify the `MODPACK_URL` is correct and accessible
2. Check your internet connection
3. Try downloading the modpack manually to verify the URL
4. Some CurseForge URLs may expire - get a fresh download link

## Additional Resources

- [CurseForge Modpacks](https://www.curseforge.com/minecraft/modpacks)
- [Forge Documentation](https://docs.minecraftforge.net/)
- [Fabric Documentation](https://fabricmc.net/wiki/)
- [Server Configuration Guide](./README.md#configuration)

## Support

If you encounter issues not covered in this guide:

1. Check the [main README troubleshooting section](./README.md#troubleshooting)
2. Review server logs for specific error messages
3. Submit an issue on the [GitHub repository](https://github.com/dmccoystephenson/private-curseforge-mc-server/issues)

---

**Remember**: Always backup before upgrading, test in a non-production environment when possible, and have a rollback plan ready.
