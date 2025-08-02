#!/bin/bash

# WireGuard Server Setup Script
# Run this on your home server/router

set -e

echo "🔧 Setting up WireGuard VPN Server..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Install WireGuard
echo "📦 Installing WireGuard..."
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y wireguard wireguard-tools
elif command -v yum &> /dev/null; then
    yum install -y epel-release
    yum install -y wireguard-tools
elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm wireguard-tools
else
    echo "❌ Unsupported package manager. Please install WireGuard manually."
    exit 1
fi

# Create WireGuard directory
mkdir -p /etc/wireguard
cd /etc/wireguard

# Generate server keys
echo "🔑 Generating server keys..."
wg genkey | tee server_private.key | wg pubkey > server_public.key
chmod 600 server_private.key

# Get server private key
SERVER_PRIVATE_KEY=$(cat server_private.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Detect network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [[ -z "$INTERFACE" ]]; then
    INTERFACE="eth0"
    echo "⚠️  Could not detect network interface, using $INTERFACE"
else
    echo "🌐 Detected network interface: $INTERFACE"
fi

# Get home network subnet
HOME_SUBNET=$(ip route | grep "$INTERFACE" | grep -E '192\.168\.|10\.|172\.' | head -n1 | awk '{print $1}')
if [[ -z "$HOME_SUBNET" ]]; then
    HOME_SUBNET="192.168.1.0/24"
    echo "⚠️  Could not detect home subnet, using $HOME_SUBNET"
else
    echo "🏠 Detected home subnet: $HOME_SUBNET"
fi

# Create server configuration
echo "📝 Creating server configuration..."
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE

# Client configurations will be added here
EOF

# Enable IP forwarding
echo "🔄 Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Create client management script
cat > /etc/wireguard/add-client.sh << 'EOF'
#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP="10.0.0.$(($(wg show wg0 peers | wc -l) + 2))"

# Generate client keys
cd /etc/wireguard
wg genkey | tee ${CLIENT_NAME}_private.key | wg pubkey > ${CLIENT_NAME}_public.key
chmod 600 ${CLIENT_NAME}_private.key

CLIENT_PRIVATE_KEY=$(cat ${CLIENT_NAME}_private.key)
CLIENT_PUBLIC_KEY=$(cat ${CLIENT_NAME}_public.key)
SERVER_PUBLIC_KEY=$(cat server_public.key)

# Add peer to server config
cat >> wg0.conf << EOL

[Peer]
# $CLIENT_NAME
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOL

# Create client config
cat > ${CLIENT_NAME}.conf << EOL
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = YOUR_DOMAIN_OR_IP:51820
AllowedIPs = 192.168.0.0/16, 10.0.0.0/24
PersistentKeepalive = 25
EOL

echo "✅ Client configuration created: ${CLIENT_NAME}.conf"
echo "📱 Send this file to your client device"
echo ""
echo "🔄 Restart WireGuard to apply changes:"
echo "   sudo systemctl restart wg-quick@wg0"
EOF

chmod +x /etc/wireguard/add-client.sh

# Configure firewall
echo "🔥 Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 51820/udp
    ufw route allow in on wg0 out on $INTERFACE
    ufw route allow in on $INTERFACE out on wg0
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=51820/udp
    firewall-cmd --permanent --add-masquerade
    firewall-cmd --reload
fi

# Enable and start WireGuard
echo "🚀 Starting WireGuard service..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo ""
echo "✅ WireGuard server setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Create client configurations:"
echo "   sudo /etc/wireguard/add-client.sh laptop"
echo "   sudo /etc/wireguard/add-client.sh phone"
echo ""
echo "2. Update client configs with your public IP/domain"
echo "3. Set up port forwarding (port 51820 UDP) or Cloudflare Tunnel"
echo ""
echo "🔑 Server public key: $SERVER_PUBLIC_KEY"
echo "🌐 Server listening on port 51820/UDP"
echo "🏠 Home network: $HOME_SUBNET"
echo "🔗 VPN network: 10.0.0.0/24"