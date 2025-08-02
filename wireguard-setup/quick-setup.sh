#!/bin/bash

# Quick WireGuard + Cloudflare Tunnel Setup
# This script helps you get started quickly

set -e

echo "🚀 WireGuard + Cloudflare Tunnel Quick Setup"
echo "============================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p wireguard-config wg-easy-data

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

# Update docker-compose.yml with user inputs
echo "📝 Updating configuration..."
sed -i.bak "s/vpn\.yourdomain\.com/$VPN_DOMAIN/g" docker-compose.yml
sed -i "s/wg-admin\.yourdomain\.com/$ADMIN_DOMAIN/g" cloudflare-tunnel-config.yml
sed -i "s/vpn\.yourdomain\.com/$VPN_DOMAIN/g" cloudflare-tunnel-config.yml
sed -i "s/your-secure-password-here/$WEB_PASSWORD/g" docker-compose.yml

# Get home network subnet
echo "🏠 Detecting home network..."
HOME_SUBNET=$(ip route | grep -E '192\.168\.|10\.|172\.' | grep -v docker | head -n1 | awk '{print $1}')
if [[ -z "$HOME_SUBNET" ]]; then
    read -p "Enter your home network subnet (e.g., 192.168.1.0/24): " HOME_SUBNET
fi
echo "Home network detected: $HOME_SUBNET"

# Update allowed IPs in docker-compose.yml
sed -i "s/192\.168\.0\.0\/16/$HOME_SUBNET/g" docker-compose.yml

# Start the services
echo "🐳 Starting WireGuard services..."
docker-compose up -d

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
echo "   docker-compose logs -f"
echo ""
echo "🛑 Stop services:"
echo "   docker-compose down"
echo ""
echo "📋 View client QR codes:"
echo "   docker-compose logs wg-easy | grep -A 10 'QR Code'"