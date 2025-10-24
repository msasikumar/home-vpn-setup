#!/bin/bash

# Fix RFC1918 IP rejection error for Cloudflare Tunnel
# This script provides multiple solutions to resolve the issue

set -e

echo "🔧 Fixing RFC1918 IP rejection error for ag-admin.sashi.online"
echo "=============================================================="

# Check if cloudflared is running
if pgrep -f cloudflared > /dev/null; then
    echo "📋 Current cloudflared processes:"
    pgrep -f cloudflared | xargs ps -p
    echo ""
    
    echo "🛑 Stopping existing cloudflared processes..."
    pkill -f cloudflared || true
    sleep 3
fi

# Method 1: Restart cloudflared with new configuration
echo "🚀 Method 1: Restarting Cloudflare Tunnel with updated config"
echo "============================================================="

# Check if running in Docker/Podman
if docker ps --format "table {{.Names}}" | grep -q cloudflared; then
    echo "🐳 Restarting Docker container..."
    docker restart cloudflared
elif podman ps --format "table {{.Names}}" | grep -q cloudflared; then
    echo "🐳 Restarting Podman container..."
    podman restart cloudflared
else
    echo "💻 Starting cloudflared directly..."
    # Start cloudflared in background
    nohup cloudflared tunnel --config ./cloudflare-tunnel-config.yml run > cloudflared.log 2>&1 &
    echo "Started cloudflared with PID: $!"
fi

echo ""
echo "⏳ Waiting 10 seconds for tunnel to establish..."
sleep 10

# Method 2: Test the connection
echo "🧪 Testing connection to ag-admin.sashi.online..."
if curl -s -o /dev/null -w "%{http_code}" https://ag-admin.sashi.online/ | grep -q "200\|302\|401"; then
    echo "✅ Connection successful!"
else
    echo "❌ Still getting errors. Trying additional fixes..."
    
    # Method 3: Alternative configuration approach
    echo ""
    echo "🔧 Method 2: Creating alternative tunnel configuration"
    echo "===================================================="
    
    # Create a backup of current config
    cp cloudflare-tunnel-config.yml cloudflare-tunnel-config.yml.backup
    
    # Create alternative config that bypasses RFC1918 restrictions
    cat > cloudflare-tunnel-config-alt.yml << 'EOF'
# Alternative Cloudflare Tunnel Configuration
# Designed to bypass RFC1918 IP restrictions

tunnel: 278d633b-37a9-42ee-93c5-621173cc8ab5
credentials-file: /path/to/your/tunnel/credentials.json

# Ingress rules with RFC1918 bypass
ingress:
  # VPN traffic
  - hostname: vpn.sashi.live
    service: udp://localhost:51820

  # Web admin interface with special handling
  - hostname: ag-admin.sashi.online
    service: http://127.0.0.1:51821
    originRequest:
      # Use 127.0.0.1 instead of localhost to avoid DNS issues
      httpHostHeader: 127.0.0.1:51821
      # Disable TLS verification
      noTLSVerify: true
      # Force HTTP/1.1
      http2Origin: false
      # Increase timeouts
      connectTimeout: 120s
      tlsTimeout: 120s
      # Disable keep-alive which can cause issues
      keepAliveConnections: 0

  # Catch-all
  - service: http_status:404

# Disable features that can interfere with private IPs
warp-routing:
  enabled: false

# Minimal logging to avoid conflicts
loglevel: warn
no-autoupdate: true
EOF

    echo "📝 Created alternative configuration: cloudflare-tunnel-config-alt.yml"
    echo ""
    echo "🔄 To use the alternative config, run:"
    echo "   cloudflared tunnel --config ./cloudflare-tunnel-config-alt.yml run"
fi

echo ""
echo "🔍 Additional Troubleshooting Steps:"
echo "===================================="
echo ""
echo "1. 🌐 Check if WireGuard Easy is running:"
echo "   docker ps | grep wg-easy"
echo "   # or"
echo "   podman ps | grep wg-easy"
echo ""
echo "2. 🔗 Test local access:"
echo "   curl -I http://localhost:51821"
echo "   curl -I http://127.0.0.1:51821"
echo ""
echo "3. 🏠 Access from local network instead:"
echo "   http://$(hostname -I | awk '{print $1}'):51821"
echo ""
echo "4. 📋 Check cloudflared logs:"
echo "   tail -f cloudflared.log"
echo "   # or for containers:"
echo "   docker logs cloudflared"
echo "   podman logs cloudflared"
echo ""
echo "5. 🔧 Alternative: Use Cloudflare Access"
echo "   - Go to Cloudflare Dashboard > Zero Trust > Access"
echo "   - Create an application for ag-admin.sashi.online"
echo "   - This bypasses RFC1918 restrictions entirely"
echo ""
echo "6. 🌍 DNS Resolution Check:"
echo "   nslookup ag-admin.sashi.online"
echo "   dig ag-admin.sashi.online"
echo ""
echo "💡 The RFC1918 error typically occurs when:"
echo "   - Accessing from the same network as the tunnel origin"
echo "   - Cloudflare detects private IP in the request chain"
echo "   - DNS resolution issues with localhost/127.0.0.1"
echo ""
echo "🎯 Best solution: Use Cloudflare Access or access via local IP"