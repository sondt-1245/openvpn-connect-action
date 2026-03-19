#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/tmp/vpn.ovpn"
LOG_FILE="/tmp/openvpn.log"
PID_FILE="/tmp/openvpn.pid"

# ── Write base config file ──
if [ -z "${OVPN_CONFIG:-}" ]; then
  echo "::error::OpenVPN config content is required but was empty"
  exit 1
fi

echo "$OVPN_CONFIG" > "$CONFIG_FILE"
echo "Base config written to $CONFIG_FILE"

# ── Modify config: append directives like kota65535/github-openvpn-connect-action ──
echo "" >> "$CONFIG_FILE"
echo "# ----- modified by action -----" >> "$CONFIG_FILE"

# username & password auth
if [ -n "${OVPN_USERNAME:-}" ] && [ -n "${OVPN_PASSWORD:-}" ]; then
  printf '%s\n%s\n' "$OVPN_USERNAME" "$OVPN_PASSWORD" > /tmp/vpn-up.txt
  chmod 600 /tmp/vpn-up.txt
  echo "auth-user-pass /tmp/vpn-up.txt" >> "$CONFIG_FILE"
  echo "Username/password auth configured"
fi

# client private key
if [ -n "${OVPN_CLIENT_KEY:-}" ]; then
  echo "$OVPN_CLIENT_KEY" > /tmp/vpn-client.key
  chmod 600 /tmp/vpn-client.key
  echo "key /tmp/vpn-client.key" >> "$CONFIG_FILE"
  echo "Client key configured"
fi

# TLS auth key
if [ -n "${OVPN_TLS_AUTH_KEY:-}" ]; then
  echo "$OVPN_TLS_AUTH_KEY" > /tmp/vpn-ta.key
  chmod 600 /tmp/vpn-ta.key
  echo "tls-auth /tmp/vpn-ta.key 1" >> "$CONFIG_FILE"
  echo "TLS auth key configured"
fi

# TLS crypt key
if [ -n "${OVPN_TLS_CRYPT_KEY:-}" ]; then
  echo "$OVPN_TLS_CRYPT_KEY" > /tmp/vpn-tc.key
  chmod 600 /tmp/vpn-tc.key
  echo "tls-crypt /tmp/vpn-tc.key 1" >> "$CONFIG_FILE"
  echo "TLS crypt key configured"
fi

# TLS crypt v2 key
if [ -n "${OVPN_TLS_CRYPT_V2_KEY:-}" ]; then
  echo "$OVPN_TLS_CRYPT_V2_KEY" > /tmp/vpn-tcv2.key
  chmod 600 /tmp/vpn-tcv2.key
  echo "tls-crypt-v2 /tmp/vpn-tcv2.key 1" >> "$CONFIG_FILE"
  echo "TLS crypt v2 key configured"
fi

# ── Echo config for debugging ──
if [ "${OVPN_ECHO_CONFIG:-true}" = "true" ]; then
  echo "========== begin configuration =========="
  cat "$CONFIG_FILE"
  echo "=========== end configuration ==========="
fi

# ── Start OpenVPN ──
echo "Starting OpenVPN..."
sudo openvpn \
  --config "$CONFIG_FILE" \
  --daemon \
  --log "$LOG_FILE" \
  --writepid "$PID_FILE"

# ── Wait for initialization (tail the log like the reference action) ──
MAX_WAIT=30
ELAPSED=0
echo "Waiting for VPN initialization (up to ${MAX_WAIT}s)..."

while [ $ELAPSED -lt $MAX_WAIT ]; do
  if sudo grep -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
    echo "VPN connected successfully after ${ELAPSED}s"
    PID=$(cat "$PID_FILE" 2>/dev/null || echo "unknown")
    echo "Daemon PID: $PID"
    break
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

if ! sudo grep -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
  echo "::error::VPN connection failed — initialization not completed within ${MAX_WAIT}s"
  echo "--- OpenVPN log ---"
  sudo cat "$LOG_FILE" || true
  exit 1
fi

# ── Optional ping verification ──
if [ -n "${OVPN_PING_URL:-}" ]; then
  echo "Verifying connectivity to $OVPN_PING_URL..."
  if ping -c 3 -W 5 "$OVPN_PING_URL" > /dev/null 2>&1; then
    echo "Ping to $OVPN_PING_URL succeeded"
  else
    echo "::warning::Ping to $OVPN_PING_URL failed — VPN may not be routing correctly"
  fi
fi

echo "OpenVPN connection established"
