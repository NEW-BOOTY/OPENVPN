#!/bin/bash
# vpn-launch.sh — Modular OpenVPN CLI utility for macOS
# Author: Devin B. Royal
# License: © 2025 Devin B. Royal. All rights reserved.

# === CONFIG ===
VPN_BASE="$HOME/vpn"
LOG_FILE="$VPN_BASE/vpn-launch.log"
DEFAULT_PROFILE="default"
VERBOSE=false

# === FUNCTIONS ===

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

create_auth_file() {
  local profile="$1"
  local auth_file="$VPN_BASE/$profile/auth.txt"
  if [[ ! -f "$auth_file" ]]; then
    read -p "Enter VPN username: " username
    read -s -p "Enter VPN password: " password
    echo -e "$username\n$password" > "$auth_file"
    chmod 600 "$auth_file"
    log INFO "Auth file created for profile '$profile'."
  fi
}

generate_ovpn_config() {
  local profile="$1"
  local config_file="$VPN_BASE/$profile/$profile.ovpn"
  local auth_file="auth.txt"

  mkdir -p "$VPN_BASE/$profile"

  cat <<EOF > "$config_file"
client
dev tun
proto udp
remote vpn.example.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass $auth_file
cipher AES-256-CBC
auth SHA256
remote-cert-tls server
redirect-gateway def1
dhcp-option DNS 8.8.8.8
verb 3
mute 20

<ca>
-----BEGIN CERTIFICATE-----
...your CA cert here...
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
...your client cert here...
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
...your private key here...
-----END PRIVATE KEY-----
</key>
EOF

  log INFO "Config file generated for profile '$profile'."
}

launch_vpn() {
  local profile="$1"
  local config_file="$VPN_BASE/$profile/$profile.ovpn"

  if [[ ! -f "$config_file" ]]; then
    log ERROR "Config file not found for profile '$profile'."
    exit 1
  fi

  log INFO "Launching OpenVPN for profile '$profile'..."
  sudo openvpn --config "$config_file" >> "$LOG_FILE" 2>&1 || {
    log ERROR "OpenVPN failed to start for profile '$profile'."
    exit 1
  }

  log SUCCESS "VPN connected successfully for profile '$profile'."
}

rotate_auth() {
  local profile="$1"
  local auth_file="$VPN_BASE/$profile/auth.txt"
  rm -f "$auth_file"
  log INFO "Auth file removed for profile '$profile'. Recreating..."
  create_auth_file "$profile"
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

PROFILE="${PROFILE:-$DEFAULT_PROFILE}"
mkdir -p "$VPN_BASE"

# === EXECUTION ===

check_openvpn

if [[ "$ROTATE_AUTH" == true ]]; then
  rotate_auth "$PROFILE"
fi

create_auth_file "$PROFILE"
generate_ovpn_config "$PROFILE"
launch_vpn "$PROFILE"
