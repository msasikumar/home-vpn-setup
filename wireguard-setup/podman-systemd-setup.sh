#!/bin/bash

# WireGuard Podman Systemd Service Setup
# This creates systemd services for better integration and auto-start

set -e

echo "🔧 Setting up WireGuard with Podman + Systemd"
echo "=============================================="

# Check if running as user (not root)
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should be run as a regular user (not root)"
   echo "   Podman works best in rootless mode for security"
   exit 1
fi

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "❌ Podman is not installed. Please run podman-quick-setup.sh first."
    exit 1
fi

# Enable lingering for user to allow services to start without login
echo "🔄 Enabling user lingering for systemd services..."
sudo loginctl enable-linger $(whoami)

# Create systemd user directory
mkdir -p ~/.config/systemd/user

# Generate systemd service files from the compose file
echo "📝 Generating systemd service files..."
podman generate systemd --new --files --name wireguard-setup_wireguard_1
podman generate systemd --new --files --name wireguard-setup_wg-easy_1
podman generate systemd --new --files --name wireguard-setup_cloudflared_1

# Move service files to user systemd directory
mv container-*.service ~/.config/systemd/user/

# Create a pod service for better management
cat > ~/.config/systemd/user/wireguard-pod.service << 'EOF'
[Unit]
Description=WireGuard VPN Pod
Wants=network-online.target
After=network-online.target
RequiresMountsFor=%t/containers

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=on-failure
TimeoutStopSec=70
ExecStartPre=/bin/rm -f %t/%n.ctr-id
ExecStart=/usr/bin/podman pod start wireguard-setup_default
ExecStop=/usr/bin/podman pod stop -t 10 wireguard-setup_default
ExecStopPost=/bin/rm -f %t/%n.ctr-id
PIDFile=%t/%n.pid
Type=forking

[Install]
WantedBy=default.target
EOF

# Create a convenience script for managing the services
cat > ~/wireguard-podman-control.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 Starting WireGuard services..."
        systemctl --user start wireguard-pod.service
        ;;
    stop)
        echo "🛑 Stopping WireGuard services..."
        systemctl --user stop wireguard-pod.service
        ;;
    restart)
        echo "🔄 Restarting WireGuard services..."
        systemctl --user restart wireguard-pod.service
        ;;
    status)
        echo "📊 WireGuard service status:"
        systemctl --user status wireguard-pod.service
        echo ""
        echo "📋 Container status:"
        podman ps --filter label=io.podman.compose.project=wireguard-setup
        ;;
    logs)
        echo "📋 WireGuard logs:"
        podman logs -f wireguard
        ;;
    enable)
        echo "🔄 Enabling WireGuard auto-start..."
        systemctl --user enable wireguard-pod.service
        ;;
    disable)
        echo "❌ Disabling WireGuard auto-start..."
        systemctl --user disable wireguard-pod.service
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable}"
        echo ""
        echo "Commands:"
        echo "  start    - Start WireGuard services"
        echo "  stop     - Stop WireGuard services"
        echo "  restart  - Restart WireGuard services"
        echo "  status   - Show service and container status"
        echo "  logs     - Show WireGuard logs (follow mode)"
        echo "  enable   - Enable auto-start on boot"
        echo "  disable  - Disable auto-start on boot"
        exit 1
        ;;
esac
EOF

chmod +x ~/wireguard-podman-control.sh

# Reload systemd user daemon
systemctl --user daemon-reload

echo ""
echo "✅ Systemd integration setup complete!"
echo "======================================"
echo ""
echo "🎮 Control your WireGuard services:"
echo "   ~/wireguard-podman-control.sh start     # Start services"
echo "   ~/wireguard-podman-control.sh stop      # Stop services"
echo "   ~/wireguard-podman-control.sh status    # Check status"
echo "   ~/wireguard-podman-control.sh logs      # View logs"
echo "   ~/wireguard-podman-control.sh enable    # Auto-start on boot"
echo ""
echo "🔧 Direct systemd commands:"
echo "   systemctl --user start wireguard-pod.service"
echo "   systemctl --user enable wireguard-pod.service"
echo "   systemctl --user status wireguard-pod.service"
echo ""
echo "📋 Podman commands:"
echo "   podman ps                               # List containers"
echo "   podman pod ls                           # List pods"
echo "   podman logs wireguard                   # Container logs"
echo ""
echo "💡 Benefits of this setup:"
echo "   - Services start automatically on boot"
echo "   - Better resource management"
echo "   - Integrated with system logging"
echo "   - No Docker daemon required"
echo "   - Rootless operation for security"