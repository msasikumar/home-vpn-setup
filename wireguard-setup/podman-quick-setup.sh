#!/bin/bash

# Quick WireGuard + Cloudflare Tunnel Setup with Podman
# This script helps you get started quickly

set -e

echo "🚀 WireGuard + Cloudflare Tunnel Quick Setup (Podman)"
echo "===================================================="

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "❌ Podman is not installed. Installing Podman..."
    
    # Install Podman based on the distribution
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y podman podman-compose
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y podman podman-compose
    elif command -v yum &> /dev/null; then
        sudo yum install -y podman podman-compose
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm podman podman-compose
    else
        echo "❌ Unsupported package manager. Please install Podman manually."
        exit 1
    fi
fi

# Check if podman-compose is available, fallback to docker-compose syntax
COMPOSE_CMD="podman-compose"
if ! command -v podman-compose &> /dev/null; then
    if command -v docker-compose &> /dev/null; then
        echo "⚠️  Using docker-compose with podman backend"
        export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
        COMPOSE_CMD="docker-compose"
    else
        echo "❌ Neither podman-compose nor docker-compose is available."
        echo "Installing docker-compose for podman compatibility..."
        
        # Install docker-compose
        if command -v pip3 &> /dev/null; then
            pip3 install --user docker-compose
        else
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /tmp/docker-compose
            sudo mv /tmp/docker-compose /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
        export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
        COMPOSE_CMD="docker-compose"
    fi
fi

# Enable podman socket for docker-compose compatibility if needed
if [[ "$COMPOSE_CMD" == "docker-compose" ]]; then
    echo "🔌 Enabling Podman socket for Docker Compose compatibility..."
    systemctl --user enable --now podman.socket
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p wireguard-config wg-easy-data

# Set SELinux context for volumes if SELinux is enabled
if command -v getenforce &> /dev/null && [[ "$(getenforce)" != "Disabled" ]]; then
    echo "🔒 Setting SELinux contexts for volumes..."
    sudo setsebool -P container_manage_cgroup true
    chcon -Rt container_file_t wireguard-config/ wg-easy-data/ 2>/dev/null || true
fi

# Check if Cloudflare tunnel is already set up
if [[ ! -f "tunnel-credentials.json" ]]; then
    echo ""
    echo "🔧 Cloudflare Tunnel Setup Required"
    echo "===================================="
    echo "You need to set up a Cloudflare Tunnel first:"
    echo ""
    echo "1. Install cloudflared:"
    echo "   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
    echo "   sudo dpkg -i cloudflared.deb"
    echo ""
    echo "2. Login to Cloudflare:"
    echo "   cloudflared tunnel login"
    echo ""
    echo "3. Create a tunnel:"
    echo "   cloudflared tunnel create home-vpn"
    echo ""
    echo "4. Copy the credentials file to this directory as 'tunnel-credentials.json'"
    echo ""
    echo "5. Update 'cloudflare-tunnel-config.yml' with your tunnel ID and domain"
    echo ""
    echo "6. Add DNS records in Cloudflare dashboard:"
    echo "   - vpn.yourdomain.com -> your-tunnel-id.cfargotunnel.com"
    echo "   - wg-admin.yourdomain.com -> your-tunnel-id.cfargotunnel.com"
    echo ""
    read -p "Press Enter when you've completed the Cloudflare setup..."
fi

# Prompt for domain configuration
echo ""
echo "🌐 Domain Configuration"
echo "======================="
read -p "Enter your VPN domain (e.g., vpn.yourdomain.com): " VPN_DOMAIN
read -p "Enter your admin panel domain (e.g., wg-admin.yourdomain.com): " ADMIN_DOMAIN
read -s -p "Enter a secure password for the web UI: " WEB_PASSWORD
echo ""

# Update podman-compose.yml with user inputs
echo "📝 Updating configuration..."
cp podman-compose.yml podman-compose.yml.bak
sed -i "s/vpn\.yourdomain\.com/$VPN_DOMAIN/g" podman-compose.yml
sed -i "s/wg-admin\.yourdomain\.com/$ADMIN_DOMAIN/g" cloudflare-tunnel-config.yml
sed -i "s/vpn\.yourdomain\.com/$VPN_DOMAIN/g" cloudflare-tunnel-config.yml
sed -i "s/your-secure-password-here/$WEB_PASSWORD/g" podman-compose.yml

# Get home network subnet
echo "🏠 Detecting home network..."
HOME_SUBNET=$(ip route | grep -E '192\.168\.|10\.|172\.' | grep -v docker | grep -v podman | head -n1 | awk '{print $1}')
if [[ -z "$HOME_SUBNET" ]]; then
    read -p "Enter your home network subnet (e.g., 192.168.1.0/24): " HOME_SUBNET
fi
echo "Home network detected: $HOME_SUBNET"

# Update allowed IPs in podman-compose.yml
sed -i "s/192\.168\.0\.0\/16/$HOME_SUBNET/g" podman-compose.yml

# Pull images first to avoid timeout issues
echo "📥 Pulling container images..."
podman pull docker.io/linuxserver/wireguard:latest
podman pull docker.io/weejewel/wg-easy:latest
podman pull docker.io/cloudflare/cloudflared:latest

# Start the services
echo "🐳 Starting WireGuard services with Podman..."
if [[ "$COMPOSE_CMD" == "podman-compose" ]]; then
    podman-compose -f podman-compose.yml up -d
else
    docker-compose -f podman-compose.yml up -d
fi

echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "🌐 Services:"
echo "   - VPN Server: $VPN_DOMAIN:51820"
echo "   - Web Admin: https://$ADMIN_DOMAIN"
echo "   - Password: $WEB_PASSWORD"
echo ""
echo "📱 Next Steps:"
echo "1. Wait 2-3 minutes for services to start"
echo "2. Visit https://$ADMIN_DOMAIN to manage clients"
echo "3. Create client configurations through the web UI"
echo "4. Download client configs and install WireGuard app"
echo ""
echo "🔍 Check status:"
echo "   podman ps"
echo "   $COMPOSE_CMD -f podman-compose.yml logs -f"
echo ""
echo "🛑 Stop services:"
echo "   $COMPOSE_CMD -f podman-compose.yml down"
echo ""
echo "📋 View client QR codes:"
echo "   $COMPOSE_CMD -f podman-compose.yml logs wg-easy | grep -A 10 'QR Code'"
echo ""
echo "🔧 Podman-specific commands:"
echo "   podman pod ls                    # List pods"
echo "   podman logs wireguard           # View container logs"
echo "   podman exec -it wireguard bash  # Access container shell"