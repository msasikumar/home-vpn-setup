#!/bin/bash

# Tailscale Setup Script - Zero-config VPN alternative
# This is the easiest option for home network access

set -e

echo "🌐 Tailscale Setup - Zero-Config VPN"
echo "===================================="

# Check if running as root for some commands
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Don't run this script as root. Run as your regular user."
   exit 1
fi

# Detect OS and install Tailscale
echo "📦 Installing Tailscale..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux installation
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
        sudo apt-get update
        sudo apt-get install -y tailscale
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/tailscale.repo
        sudo yum install -y tailscale
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S --noconfirm tailscale
    else
        echo "❌ Unsupported Linux distribution. Please install Tailscale manually."
        echo "Visit: https://tailscale.com/download"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
        brew install tailscale
    else
        echo "❌ Homebrew not found. Please install Tailscale manually from:"
        echo "https://tailscale.com/download/mac"
        exit 1
    fi
else
    echo "❌ Unsupported operating system. Please install Tailscale manually."
    echo "Visit: https://tailscale.com/download"
    exit 1
fi

# Enable and start Tailscale service (Linux only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🚀 Starting Tailscale service..."
    sudo systemctl enable --now tailscaled
fi

# Get home network subnet
echo "🏠 Detecting home network..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    HOME_SUBNET=$(ip route | grep -E '192\.168\.|10\.|172\.' | grep -v tailscale | head -n1 | awk '{print $1}')
elif [[ "$OSTYPE" == "darwin"* ]]; then
    HOME_SUBNET=$(route -n get default | grep interface | awk '{print $2}' | xargs ifconfig | grep inet | grep -E '192\.168\.|10\.|172\.' | head -n1 | awk '{print $2}' | sed 's/\.[0-9]*$/.0\/24/')
fi

if [[ -z "$HOME_SUBNET" ]]; then
    echo "⚠️  Could not auto-detect home network subnet."
    read -p "Enter your home network subnet (e.g., 192.168.1.0/24): " HOME_SUBNET
fi

echo "Home network detected: $HOME_SUBNET"

# Connect to Tailscale and advertise routes
echo ""
echo "🔗 Connecting to Tailscale..."
echo "This will open a browser window for authentication."
echo ""

# Start Tailscale and advertise home network routes
sudo tailscale up --advertise-routes="$HOME_SUBNET" --accept-dns=false

echo ""
echo "✅ Tailscale setup complete!"
echo ""
echo "📋 Next Steps:"
echo "=============="
echo ""
echo "1. **Approve subnet routes** in Tailscale Admin Console:"
echo "   - Visit: https://login.tailscale.com/admin/machines"
echo "   - Find this machine in the list"
echo "   - Click the '...' menu → 'Edit route settings'"
echo "   - Approve the subnet route for $HOME_SUBNET"
echo ""
echo "2. **Install Tailscale on your remote devices:**"
echo "   - Download from: https://tailscale.com/download"
echo "   - Login with the same account"
echo "   - Devices will automatically connect"
echo ""
echo "3. **Test the connection:**"
echo "   - From remote device, try: ping $(hostname -I | awk '{print $1}')"
echo "   - Access home devices using their local IP addresses"
echo ""
echo "🔧 Useful Commands:"
echo "==================="
echo "# Check Tailscale status"
echo "tailscale status"
echo ""
echo "# Show IP addresses"
echo "tailscale ip"
echo ""
echo "# Disconnect"
echo "sudo tailscale down"
echo ""
echo "# Reconnect"
echo "sudo tailscale up --advertise-routes=$HOME_SUBNET"
echo ""
echo "🌟 Advantages of Tailscale:"
echo "==========================="
echo "✅ Zero configuration - works behind NAT/firewalls"
echo "✅ Automatic device discovery"
echo "✅ Built-in access controls"
echo "✅ Works on all platforms"
echo "✅ No port forwarding needed"
echo "✅ Mesh networking between all devices"
echo ""
echo "🔒 Security Features:"
echo "====================="
echo "✅ End-to-end encryption"
echo "✅ Key rotation"
echo "✅ Device authentication"
echo "✅ Network access controls"
echo "✅ Activity logging"