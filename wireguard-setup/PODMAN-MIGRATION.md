# Docker to Podman Migration Guide

## Why Migrate to Podman?

### Security Benefits
- **Rootless containers**: Run containers without root privileges
- **No daemon**: Eliminates single point of failure and attack surface
- **Better SELinux integration**: Enhanced security on RHEL/Fedora systems
- **Daemonless architecture**: More secure privilege handling

### Operational Benefits
- **Systemd integration**: Native service management and auto-restart
- **Resource efficiency**: No background daemon consuming resources
- **Docker compatibility**: Drop-in replacement for most Docker commands
- **Pod support**: Native multi-container orchestration like Kubernetes

### VPN-Specific Advantages
- More secure handling of `NET_ADMIN` capabilities
- Better integration with host networking and firewall rules
- More reliable container restart policies
- Easier troubleshooting and logging

## Migration Steps

### 1. Stop Current Docker Services
```bash
cd home-vpn-setup/wireguard-setup
docker-compose down
```

### 2. Install Podman
The migration scripts will handle installation, but you can also install manually:

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y podman podman-compose
```

**RHEL/Fedora/CentOS:**
```bash
sudo dnf install -y podman podman-compose
```

**Arch Linux:**
```bash
sudo pacman -S podman podman-compose
```

### 3. Quick Migration (Recommended)
```bash
chmod +x podman-quick-setup.sh
./podman-quick-setup.sh
```

This script will:
- Install Podman if not present
- Set up Docker Compose compatibility
- Configure SELinux contexts if needed
- Migrate your existing configuration
- Start services with Podman

### 4. Advanced: Systemd Integration
For production deployments, use systemd integration:
```bash
chmod +x podman-systemd-setup.sh
./podman-systemd-setup.sh
```

This provides:
- Auto-start on boot
- Better service management
- System logging integration
- Rootless operation

## Key Differences from Docker

### Volume Mounts
Podman uses SELinux labels for security:
```yaml
# Docker
volumes:
  - ./config:/config

# Podman (with SELinux)
volumes:
  - ./config:/config:Z
```

### Image References
Podman requires full registry paths:
```yaml
# Docker
image: linuxserver/wireguard:latest

# Podman
image: docker.io/linuxserver/wireguard:latest
```

### Networking
Podman uses different default networks but maintains compatibility.

### Commands Comparison

| Docker | Podman | Notes |
|--------|--------|-------|
| `docker run` | `podman run` | Direct replacement |
| `docker-compose up` | `podman-compose up` | Requires podman-compose |
| `docker ps` | `podman ps` | Same syntax |
| `docker logs` | `podman logs` | Same syntax |
| `docker exec` | `podman exec` | Same syntax |

## File Structure After Migration

```
wireguard-setup/
├── docker-compose.yml          # Original Docker setup
├── podman-compose.yml          # New Podman setup
├── quick-setup.sh              # Original Docker script
├── podman-quick-setup.sh       # New Podman script
├── podman-systemd-setup.sh     # Systemd integration
├── server-setup.sh             # Unchanged
├── cloudflare-tunnel-config.yml # Unchanged
└── README.md                   # Updated documentation
```

## Managing Services

### With podman-compose
```bash
# Start services
podman-compose -f podman-compose.yml up -d

# Stop services
podman-compose -f podman-compose.yml down

# View logs
podman-compose -f podman-compose.yml logs -f

# Check status
podman ps
```

### With Systemd (after running podman-systemd-setup.sh)
```bash
# Use the control script
~/wireguard-podman-control.sh start
~/wireguard-podman-control.sh stop
~/wireguard-podman-control.sh status
~/wireguard-podman-control.sh logs

# Direct systemd commands
systemctl --user start wireguard-pod.service
systemctl --user enable wireguard-pod.service
systemctl --user status wireguard-pod.service
```

## Troubleshooting

### SELinux Issues
If you encounter permission errors:
```bash
# Set SELinux contexts
sudo setsebool -P container_manage_cgroup true
chcon -Rt container_file_t ./wireguard-config/ ./wg-easy-data/
```

### Socket Permissions
For Docker Compose compatibility:
```bash
systemctl --user enable --now podman.socket
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
```

### Container Not Starting
Check logs and permissions:
```bash
podman logs wireguard
podman inspect wireguard
```

## Performance Comparison

| Aspect | Docker | Podman |
|--------|--------|--------|
| Memory Usage | Higher (daemon) | Lower (no daemon) |
| Startup Time | Slower | Faster |
| Security | Good | Better (rootless) |
| System Integration | Limited | Excellent (systemd) |
| Resource Overhead | Higher | Lower |

## Rollback Plan

If you need to rollback to Docker:
```bash
# Stop Podman services
podman-compose -f podman-compose.yml down
# or
systemctl --user stop wireguard-pod.service

# Start Docker services
docker-compose up -d
```

Your original Docker configuration remains unchanged.

## Conclusion

Migrating to Podman provides significant security and operational benefits, especially for VPN services that require elevated privileges. The migration is straightforward with the provided scripts, and you can always rollback if needed.

The systemd integration makes Podman particularly suitable for production deployments where reliability and automatic service management are important.