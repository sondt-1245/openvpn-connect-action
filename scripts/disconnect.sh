#!/usr/bin/env bash
set -euo pipefail

echo "Disconnecting OpenVPN..."

# ── Kill OpenVPN process ──
if [ -f /tmp/openvpn.pid ]; then
  PID=$(sudo cat /tmp/openvpn.pid)
  if sudo kill "$PID" 2>/dev/null; then
    echo "Stopped OpenVPN process (PID $PID)"
  else
    echo "OpenVPN process (PID $PID) was not running"
  fi
  sudo rm -f /tmp/openvpn.pid
else
  sudo killall openvpn 2>/dev/null && echo "Stopped OpenVPN via killall" || echo "No OpenVPN process found"
fi

# ── Cleanup temp files ──
sudo rm -f \
  /tmp/vpn.ovpn \
  /tmp/vpn-up.txt \
  /tmp/vpn-client.key \
  /tmp/vpn-ta.key \
  /tmp/vpn-tc.key \
  /tmp/vpn-tcv2.key \
  /tmp/openvpn.log
echo "Cleaned up temporary files"

echo "OpenVPN disconnected"
