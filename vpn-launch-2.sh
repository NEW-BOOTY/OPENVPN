#!/bin/bash
# vpn-launch.sh — JSON-driven OpenVPN CLI utility for macOS
# Author: Devin B. Royal
# License: © 2025 Devin B. Royal. All rights reserved.

VPN_BASE="$HOME/vpn"
CONFIG_JSON="$VPN_BASE/vpn-profile.json"
LOG_FILE="$VPN_BASE/vpn-launch.log"
VERBOSE=false
ROTATE_AUTH=false
PROFILE="default"

log() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

check_openvpn() {
  if ! command -v openvpn &>/dev/null; then
    log INFO "Installing OpenVPN via Homebrew..."
    brew install openvpn || {
      log ERROR "OpenVPN installation failed."
      exit 1
    }
  else
    log INFO "OpenVPN is already installed."
  fi
}

parse_json() {
  local key="$1"
  jq -r ".profiles.\"$PROFILE\".$key" "$CONFIG_JSON"
}

create_auth_file() {
  local auth_file="$VPN_BASE/$PROFILE/auth.txt"
  local username password

  if [[ "$ROTATE_AUTH" == true || ! -f "$auth_file" ]]; then
    username=$(parse_json "username")
    password=$(parse_json "password")
    echo -e "$username\n$password" > "$auth_file"
    chmod 600 "$auth_file"
    log INFO "Auth file created for profile '$PROFILE'."
  fi
}

generate_ovpn_config() {
  local config_file="$VPN_BASE/$PROFILE/$PROFILE.ovpn"
  local server port proto
  local ca_cert client_cert client_key

  mkdir -p "$VPN_BASE/$PROFILE"

  server=$(parse_json "server")
  port=$(parse_json "port")
  proto=$(parse_json "proto")
  ca_cert=$(parse_json "ca_cert")
  client_cert=$(parse_json "client_cert")
  client_key=$(parse_json "client_key")

  cat <<EOF > "$config_file"
client
dev tun
proto $proto
remote $server $port
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass auth.txt
cipher AES-256-CBC
auth SHA256
remote-cert-tls server
redirect-gateway def1
dhcp-option DNS 8.8.8.8
verb 3
mute 20

<ca>
$ca_cert
</ca>

<cert>
$client_cert
</cert>

<key>
$client_key
</key>
EOF

  log INFO "Config file generated for profile '$PROFILE'."
}

launch_vpn() {
  local config_file="$VPN_BASE/$PROFILE/$PROFILE.ovpn"
  log INFO "Launching OpenVPN for profile '$PROFILE'..."
  sudo openvpn --config "$config_file" >> "$LOG_FILE" 2>&1 || {
    log ERROR "OpenVPN failed to start for profile '$PROFILE'."
    exit 1
  }
  log SUCCESS "VPN connected successfully for profile '$PROFILE'."
}

# === ARG PARSING ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --rotate-auth)
      ROTATE_AUTH=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# === EXECUTION ===
mkdir -p "$VPN_BASE"
check_openvpn
create_auth_file
generate_ovpn_config
launch_vpn
