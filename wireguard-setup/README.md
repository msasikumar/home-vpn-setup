# WireGuard VPN Setup with Cloudflare Tunnel

This setup provides full home network access when you're away, using WireGuard VPN secured through Cloudflare Tunnel.

## 🎯 What This Gives You

- **Full LAN Access**: Connect to all devices on your home network (192.168.x.x)
- **Secure Connection**: Traffic encrypted through WireGuard + Cloudflare
- **No Port Forwarding**: Uses Cloudflare Tunnel instead of exposing ports
- **Easy Management**: Web UI for adding/removing clients
- **Multiple Devices**: Support for phones, laptops, tablets

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)
```bash
chmod +x quick-setup.sh
./quick-setup.sh
```

### Option 2: Manual Setup

1. **Set up Cloudflare Tunnel**:
   ```bash
   # Install cloudflared
   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared.deb
   
   # Login and create tunnel
   cloudflared tunnel login
   cloudflared tunnel create home-vpn
   ```

2. **Configure DNS Records** in Cloudflare Dashboard:
   - `vpn.yourdomain.com` → `your-tunnel-id.cfargotunnel.com`
   - `wg-admin.yourdomain.com` → `your-tunnel-id.cfargotunnel.com`

3. **Update Configuration Files**:
   - Edit `cloudflare-tunnel-config.yml` with your tunnel ID and domains
   - Edit `docker-compose.yml` with your domains and password
   - Copy tunnel credentials to `tunnel-credentials.json`

4. **Start Services**:
   ```bash
   docker-compose up -d
   ```

## 📱 Client Setup

### Using Web UI (Easiest)
1. Visit `https://wg-admin.yourdomain.com`
2. Login with your password
3. Click "Add Client"
4. Scan QR code with WireGuard app or download config file

### Manual Client Configuration
Create a file like `laptop.conf`:
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.0.0.2/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <server-public-key>
Endpoint = vpn.yourdomain.com:51820
AllowedIPs = 192.168.0.0/16, 10.0.0.0/24
PersistentKeepalive = 25
```

## 🔧 Management Commands

```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update services
docker-compose pull
docker-compose up -d

# View WireGuard status
docker exec wireguard wg show
```

## 🌐 Network Layout

```
Internet → Cloudflare → Your Home → WireGuard Server
                                  ↓
                            Home Network (192.168.x.x)
                                  ↓
                            Your Devices
```

**VPN Network**: `10.0.0.0/24`
- Server: `10.0.0.1`
- Clients: `10.0.0.2`, `10.0.0.3`, etc.

**Home Network**: `192.168.x.x` (your actual home network)

## 🔒 Security Features

- **End-to-End Encryption**: WireGuard protocol
- **No Direct Exposure**: Hidden behind Cloudflare
- **Key-Based Authentication**: No passwords for VPN
- **Network Isolation**: VPN clients can't see each other
- **DDoS Protection**: Cloudflare's built-in protection

## 📊 Monitoring

### Check Connection Status
```bash
# Server side
docker exec wireguard wg show

# Client side (on your device)
wg show
```

### View Active Connections
```bash
# See connected clients
docker-compose logs wg-easy | grep "Client connected"

# Monitor traffic
docker exec wireguard wg show all transfer
```

## 🛠 Troubleshooting

### Common Issues

**Can't connect to VPN**:
1. Check Cloudflare DNS records
2. Verify tunnel is running: `docker-compose logs cloudflared`
3. Test endpoint: `nslookup vpn.yourdomain.com`

**Can access VPN but not home network**:
1. Check AllowedIPs in client config
2. Verify home network subnet in docker-compose.yml
3. Check routing: `ip route` on server

**Slow connection**:
1. Try different Cloudflare data centers
2. Adjust MTU size in client config: `MTU = 1420`
3. Check for packet loss: `ping -c 10 10.0.0.1`

### Logs and Diagnostics
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs wireguard
docker-compose logs cloudflared
docker-compose logs wg-easy

# Real-time logs
docker-compose logs -f --tail=50
```

## 🔄 Backup and Recovery

### Backup Configuration
```bash
# Backup all configs
tar -czf wireguard-backup-$(date +%Y%m%d).tar.gz \
  wireguard-config/ wg-easy-data/ \
  docker-compose.yml cloudflare-tunnel-config.yml \
  tunnel-credentials.json
```

### Restore Configuration
```bash
# Extract backup
tar -xzf wireguard-backup-YYYYMMDD.tar.gz

# Restart services
docker-compose up -d
```

## 📈 Performance Optimization

### Server Optimization
```bash
# Increase network buffers
echo 'net.core.rmem_max = 26214400' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 26214400' >> /etc/sysctl.conf
sysctl -p
```

### Client Optimization
Add to client config:
```ini
[Interface]
MTU = 1420
```

## 🆘 Support

### Getting Help
1. Check logs first: `docker-compose logs`
2. Test basic connectivity: `ping 10.0.0.1`
3. Verify DNS resolution: `nslookup vpn.yourdomain.com`
4. Check Cloudflare tunnel status in dashboard

### Useful Resources
- [WireGuard Documentation](https://www.wireguard.com/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🔐 Security Best Practices

1. **Regular Updates**: Keep containers updated
2. **Strong Passwords**: Use complex web UI password
3. **Key Rotation**: Regenerate keys periodically
4. **Access Logging**: Monitor connection logs
5. **Network Segmentation**: Limit VPN access to necessary subnets
6. **Backup Keys**: Store configuration backups securely

---

**Need help?** Check the troubleshooting section or review the logs for specific error messages.