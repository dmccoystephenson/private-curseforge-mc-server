# Private CurseForge Minecraft Server

[![CI Pipeline](https://github.com/dmccoystephenson/private-curseforge-mc-server/workflows/CI%20Pipeline/badge.svg?branch=main)](https://github.com/dmccoystephenson/private-curseforge-mc-server/actions)

A Docker-based private Minecraft server for running CurseForge modpacks with easy deployment and management.

## Features

- **CurseForge Modpack Support**: Run any CurseForge modpack easily
- **Docker Containerized**: Easy deployment and management
- **Configurable**: Environment-based configuration
- **Persistent Data**: Server data persists across container restarts
- **Easy Management**: Simple scripts for starting and stopping the server
- **Graceful Shutdown**: Ensures data integrity by properly shutting down the server

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://git-scm.com/downloads)
- A CurseForge modpack download URL

## Quick Start

### Option 1: Quick Start with Default Server (No Modpack Required)

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd private-curseforge-mc-server
   ```

2. **Configure the server**
   ```bash
   cp sample.env .env
   # The default configuration will work out of the box!
   ```

3. **Start the server**
   ```bash
   chmod +x up.sh down.sh
   ./up.sh
   ```
   
   **Note**: The first build will take 5-10 minutes as it downloads and installs Forge.

4. **Connect to your server**
   - Server address: `localhost:25565` (or your server's IP)
   - You'll have a vanilla Forge server ready to add mods to!

### Option 2: Start with a CurseForge Modpack

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd private-curseforge-mc-server
   ```

2. **Configure the server**
   ```bash
   cp sample.env .env
   # Edit .env with your settings (see Configuration section)
   ```

3. **Get your CurseForge modpack URL**
   - Visit [CurseForge](https://www.curseforge.com/minecraft/modpacks)
   - Find the modpack you want to use
   - Click "Download" and copy the download link
   - Paste this URL into the `MODPACK_URL` field in your `.env` file

4. **Start the server**
   ```bash
   chmod +x up.sh down.sh
   ./up.sh
   ```
   
   **Note**: The first build will take 5-10 minutes as it downloads and extracts the modpack.

5. **Connect to your server**
   - Server address: `localhost:25565` (or your server's IP)
   - Make sure you have the same mods installed on your client
   - The server will take a few minutes to start on first run

## Configuration

Copy `sample.env` to `.env` and modify the following settings:

### CurseForge Modpack Settings (Optional)
- `MODPACK_URL`: The download URL from CurseForge (leave empty for default Forge server)
- `MODPACK_VERSION`: Version identifier for your reference

### Default Server Settings (when no modpack is provided)
- `MINECRAFT_VERSION`: Minecraft version to use (default: 1.21.1)
- `MOD_LOADER`: Mod loader to use - `forge` or `fabric` (default: forge)

### Essential Settings
- `OPERATOR_UUID`: Your Minecraft player UUID (get from [mcuuid.net](https://mcuuid.net/))
- `OPERATOR_NAME`: Your Minecraft username
- `SERVER_MOTD`: Message displayed in the server list
- `MAX_PLAYERS`: Maximum number of players allowed

**Note**: If `OPERATOR_UUID` and `OPERATOR_NAME` are not properly configured, the server will still start but you'll need to manually add operators using the `op <username>` command in the server console.

### Server Settings
- `DIFFICULTY`: Server difficulty (peaceful, easy, normal, hard)
- `GAMEMODE`: Default game mode (survival, creative, adventure, spectator)
- `PVP_ENABLED`: Enable/disable player vs player combat
- `ONLINE_MODE`: Enable Mojang authentication (set to false for offline/cracked servers)

### Docker Configuration (for Parallel Servers)

These settings allow you to run multiple server instances in parallel without conflicts:

- `CONTAINER_NAME`: Docker container name (default: `private-curseforge-mc-server`)
- `HOST_PORT`: Host port for Minecraft server (default: `25565`)
- `HOST_RCON_PORT`: Host port for RCON (default: `8100`)
- `VOLUME_NAME`: Docker volume name for persistent data (default: `mcserver-curseforge`)

**Running Parallel Development Servers**: To run multiple servers simultaneously (e.g., for testing different configurations), create separate `.env` files with different values for these settings and use `docker compose --env-file <env-file>` to start each server.

Example for a second server:
```bash
# Create a separate env file for the second server
cp sample.env .env.dev2
# Edit .env.dev2 and change:
# - CONTAINER_NAME=private-curseforge-mc-server-dev2
# - HOST_PORT=25566
# - HOST_RCON_PORT=8101
# - VOLUME_NAME=mcserver-curseforge-dev2

# Start the second server
docker compose --env-file .env.dev2 up -d --build
```

## Management

### Starting the Server
```bash
./up.sh
```
or
```bash
docker compose up -d --build
```

### Stopping the Server
```bash
./down.sh
```
or
```bash
docker compose down
```

**Note**: The server includes graceful shutdown handling that automatically sends the "stop" command to Minecraft when the container is stopped. This ensures that mods and data save properly, preventing data loss that could occur with an abrupt termination.

### Viewing Server Logs
```bash
docker logs -f private-curseforge-mc-server
```

**Note**: Replace `private-curseforge-mc-server` with your `CONTAINER_NAME` value if you've customized it.

## File Management

### Backup Server Data
```bash
docker cp private-curseforge-mc-server:/mcserver ./backup/
```

**Note**: Replace `private-curseforge-mc-server` with your `CONTAINER_NAME` value if you've customized it.

### Restore Server Data
```bash
docker cp ./backup/ private-curseforge-mc-server:/mcserver
docker compose restart
```

**Note**: Replace `private-curseforge-mc-server` with your `CONTAINER_NAME` value if you've customized it.

### Deposit Box
The `deposit-box` directory is shared between your host system and the container at `/deposit-box`. Use it to transfer files to/from the server.

### Adding Mods
To add or update mods:
1. Place mod JARs in the `deposit-box` directory
2. Copy them to the mods folder:
   ```bash
   docker exec private-curseforge-mc-server cp /deposit-box/your-mod.jar /mcserver/mods/
   docker compose restart
   ```

## Updating

### Automated Upgrade Script

The easiest way to upgrade your modpack to a new version:

```bash
./upgrade.sh
```

This script automates the entire upgrade process:
- Stops the server gracefully
- Creates a timestamped backup automatically
- Prompts for the new modpack URL and version
- Updates configuration
- Rebuilds with the new modpack
- Starts the server

### Upgrade to a New Modpack Version

For a comprehensive, step-by-step guide to upgrading your modpack to a newer version with proper backup and rollback procedures, see the **[Upgrade Guide](UPGRADE-GUIDE.md)**.

The upgrade guide covers:
- Automated upgrade script usage (recommended)
- Manual step-by-step upgrade process
- Pre-upgrade backup procedures
- Rollback and restoration procedures
- Post-upgrade verification steps
- Troubleshooting common upgrade issues

### Quick Update (Without Modpack Change)

To update the container without changing the modpack:

```bash
./down.sh
docker compose build --no-cache
./up.sh
```

## Troubleshooting

### Server Won't Start
- Check Docker logs: `docker logs private-curseforge-mc-server` (use your `CONTAINER_NAME` value)
- Ensure all required environment variables are set
- Verify the `MODPACK_URL` is valid and accessible
- Check that you have enough disk space for the modpack
- Verify Docker and Docker Compose are installed

### Can't Connect to Server
- Ensure port 25565 is open/forwarded (or your custom `HOST_PORT` value)
- Check if `ONLINE_MODE` setting matches your client type
- Verify the server is running: `docker ps`
- Make sure you have the same mods installed on your client

### Mods Not Loading
- Check the server logs for mod loading errors
- Verify mods are in the correct `/mcserver/mods` directory
- Ensure mods are compatible with the Minecraft version
- Check for mod conflicts in the logs

### Performance Issues
- Adjust memory allocation by setting `JAVA_OPTS` environment variable
- Recommended: `-Xmx4G -Xms2G` for modded servers (4GB allocated)
- Monitor system resources: `docker stats private-curseforge-mc-server` (use your `CONTAINER_NAME` value)
- Consider reducing view distance or simulation distance

### Out of Memory Errors
- Increase memory allocation in the Docker container
- The default is 4GB (`-Xmx4G`), but some modpacks may need more
- Edit `resources/post-create.sh` and modify the `JAVA_OPTS` parameter

## Security Notes

- Change default operator settings in `.env`
- Consider setting `ONLINE_MODE=true` for authentication
- Don't expose the server publicly without proper security measures
- Regularly backup your world data
- Keep mods updated to patch security vulnerabilities

## CurseForge Modpack Notes

### Finding Modpacks
1. Visit [CurseForge Modpacks](https://www.curseforge.com/minecraft/modpacks)
2. Browse or search for modpacks
3. Check the modpack requirements (Minecraft version, mod loader)
4. Click "Download" and copy the download URL

### Server vs Client Modpacks
- Some modpacks are designed for servers, others for clients
- Server modpacks typically have server-optimized configurations
- Client-side-only mods (like minimap mods) won't affect the server

### Mod Loaders
This setup supports:
- **Forge**: Most common mod loader
- **Fabric**: Lightweight alternative to Forge

The server will automatically detect and install the appropriate mod loader from the modpack.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Development

### CI/CD Pipeline

This repository includes a comprehensive CI pipeline that automatically validates:

- **Shell Script Validation**: Syntax checking and ShellCheck linting for all bash scripts
- **Docker Configuration**: Validates Dockerfile and Docker Compose configurations
- **Environment Configuration**: Ensures all required environment variables are properly defined
- **Security Scanning**: Trivy security scanning for vulnerabilities
- **Integration Testing**: End-to-end validation of the complete setup

### Running Local CI Checks

Before submitting changes, you can run the same validation checks locally:

```bash
./scripts/ci-local.sh
```

This will run basic validation checks that mirror the CI pipeline to catch issues early.

### CI Pipeline Status

The CI pipeline runs on:
- Every push to `main` and `develop` branches
- Every pull request to `main`

Check the [Actions tab](https://github.com/dmccoystephenson/private-curseforge-mc-server/actions) for detailed CI results and logs.

## Contributing

Feel free to submit issues and enhancement requests!

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.