#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_TAG="[ai-devcontainer-template]"

# Ensure socat is available for TCP forwarding when using cached images
if ! command -v socat >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends socat
  apt-get clean && rm -rf /var/lib/apt/lists/*
fi

# Ensure agent state directories are writable by the node user
for dir in /home/node/.claude /home/node/.cursor /home/node/.codex /commandhistory; do
  mkdir -p "$dir"
  chown -R node:node "$dir"
done

# Start TCP forwarder that exposes the codex login callback (1455) on 0.0.0.0:8085
SOCAT_LISTEN_PORT=8085
CODEX_CALLBACK_PORT=1455
if ! pgrep -f "socat .*TCP-LISTEN:${SOCAT_LISTEN_PORT}" >/dev/null 2>&1; then
  nohup socat TCP-LISTEN:${SOCAT_LISTEN_PORT},fork,reuseaddr TCP:127.0.0.1:${CODEX_CALLBACK_PORT} \
    >/tmp/codex-login-forward.log 2>&1 &
fi

# Preserve Docker embedded DNS rules before flushing tables
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

if [ -n "$DOCKER_DNS_RULES" ]; then
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  while read -r rule; do
    iptables -t nat $rule
  done <<<"$DOCKER_DNS_RULES"
fi

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
  echo "ERROR failed to fetch GitHub metadata" >&2
  exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
  echo "ERROR GitHub metadata missing expected fields" >&2
  exit 1
fi

while read -r cidr; do
  if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo "ERROR invalid CIDR from GitHub metadata: $cidr" >&2
    exit 1
  fi
  ipset add -exist allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

domains=(
  "registry.npmjs.org"
  "api.openai.com"
  "auth.openai.com"
  "chatgpt.com"
  "api.anthropic.com"
  "marketplace.visualstudio.com"
  "update.code.visualstudio.com"
  "vscode.download.prss.microsoft.com"
  "download.visualstudio.microsoft.com"
  "vscode.blob.core.windows.net"
  "cursor.com"
  "api.cursor.com"
  "cursor.sh"
  "api.cursor.sh"
  "api2.cursor.sh"
  "repo42.cursor.sh"
  "downloads.cursor.com"
)

for domain in "${domains[@]}"; do
  ips=$(dig +short A "$domain")
  if [ -z "$ips" ]; then
    echo "$SCRIPT_TAG WARN: failed to resolve $domain" >&2
    continue
  fi
  while read -r ip; do
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      ipset add -exist allowed-domains "$ip"
      continue
    fi

    # Handle CNAME responses by resolving them to IPv4 addresses
    cname=${ip%.}
    cname_ips=$(dig +short A "$cname") || true
    if [ -z "$cname_ips" ]; then
      echo "$SCRIPT_TAG WARN: failed to resolve CNAME $cname for $domain" >&2
      continue
    fi
    while read -r cname_ip; do
      if [[ "$cname_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        ipset add -exist allowed-domains "$cname_ip"
      fi
    done <<<"$cname_ips"
  done <<<"$ips"
done

HOST_IP=$(ip route | awk '/default/ {print $3; exit}')
if [ -z "$HOST_IP" ]; then
  echo "ERROR failed to detect host IP" >&2
  exit 1
fi
HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')

iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Allow local OAuth callback traffic on 1455/tcp so host browser can reach CLI server
iptables -A INPUT -p tcp --dport 1455 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 1455 -j ACCEPT
# Allow the externally exposed forwarder port (8085/tcp)
iptables -A INPUT -p tcp --dport "$SOCAT_LISTEN_PORT" -j ACCEPT
iptables -A OUTPUT -p tcp --sport "$SOCAT_LISTEN_PORT" -j ACCEPT

# Redirect traffic from other interfaces to the codex login loopback listener
iptables -t nat -A PREROUTING -p tcp --dport 1455 -j REDIRECT --to-ports 1455
iptables -t nat -A OUTPUT -p tcp --dport 1455 ! -d 127.0.0.1 -j REDIRECT --to-ports 1455

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

 
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "ERROR example.com was reachable" >&2
  exit 1
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
  echo "ERROR unable to reach api.github.com" >&2
  exit 1
fi
