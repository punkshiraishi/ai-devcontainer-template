#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_TAG="[ai-devcontainer-template]"

echo "$SCRIPT_TAG Applying firewall policy"

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
  echo "$SCRIPT_TAG Restoring Docker DNS rules"
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  while read -r rule; do
    iptables -t nat $rule
  done <<<"$DOCKER_DNS_RULES"
else
  echo "$SCRIPT_TAG No Docker DNS rules detected"
fi

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

echo "$SCRIPT_TAG Fetching GitHub IP metadata"
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
  echo "$SCRIPT_TAG ERROR failed to fetch GitHub metadata" >&2
  exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
  echo "$SCRIPT_TAG ERROR GitHub metadata missing expected fields" >&2
  exit 1
fi

while read -r cidr; do
  if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo "$SCRIPT_TAG ERROR invalid CIDR from GitHub metadata: $cidr" >&2
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
  "sentry.io"
  "statsig.anthropic.com"
  "statsig.com"
  "api.figma.com"
  "www.figma.com"
  "pub.dev"
  "storage.googleapis.com"
  "pub.dartlang.org"
  "dart.dev"
  "maven.google.com"
  "dl.google.com"
  "cocoapods.org"
  "rubygems.org"
  "marketplace.visualstudio.com"
  "update.code.visualstudio.com"
  "code.visualstudio.com"
  "vscode.download.prss.microsoft.com"
  "download.visualstudio.microsoft.com"
  "vscode.blob.core.windows.net"
  "aka.ms"
  "go.microsoft.com"
  "cdn.vsassets.io"
  "msedge.net"
  "binaries.prisma.sh"
  "cursor.com"
  "api.cursor.com"
  "downloads.cursor.com"
)

echo "$SCRIPT_TAG Resolving allowlisted domains"
for domain in "${domains[@]}"; do
  ips=$(dig +short A "$domain")
  if [ -z "$ips" ]; then
    echo "$SCRIPT_TAG ERROR failed to resolve $domain" >&2
    exit 1
  fi
  while read -r ip; do
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "$SCRIPT_TAG Skipping non-IPv4 record '$ip' for $domain"
      continue
    fi
    ipset add -exist allowed-domains "$ip"
  done <<<"$ips"
done

HOST_IP=$(ip route | awk '/default/ {print $3; exit}')
if [ -z "$HOST_IP" ]; then
  echo "$SCRIPT_TAG ERROR failed to detect host IP" >&2
  exit 1
fi
HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')

echo "$SCRIPT_TAG Allowing host network $HOST_NETWORK"
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

echo "$SCRIPT_TAG Firewall rules applied"

echo "$SCRIPT_TAG Verifying outbound restrictions"
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "$SCRIPT_TAG ERROR example.com was reachable" >&2
  exit 1
else
  echo "$SCRIPT_TAG example.com blocked as expected"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
  echo "$SCRIPT_TAG ERROR unable to reach api.github.com" >&2
  exit 1
else
  echo "$SCRIPT_TAG GitHub API reachable"
fi

prisma_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://binaries.prisma.sh/ || true)
if [[ -n "$prisma_status" && "$prisma_status" != "000" ]]; then
  echo "$SCRIPT_TAG Prisma binaries host reachable (HTTP $prisma_status)"
else
  echo "$SCRIPT_TAG ERROR unable to reach binaries.prisma.sh" >&2
  exit 1
fi

figma_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://api.figma.com/v1/me -H "X-Figma-Token: test" || true)
if [[ "$figma_status" == "401" || "$figma_status" == "403" ]]; then
  echo "$SCRIPT_TAG Figma API reachable (HTTP $figma_status)"
else
  echo "$SCRIPT_TAG ERROR unexpected status $figma_status from api.figma.com" >&2
  exit 1
fi

cursor_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://api.cursor.com/status || true)
if [[ -n "$cursor_status" && "$cursor_status" != "000" ]]; then
  echo "$SCRIPT_TAG Cursor API reachable (HTTP $cursor_status)"
else
  echo "$SCRIPT_TAG ERROR unable to reach api.cursor.com" >&2
  exit 1
fi

echo "$SCRIPT_TAG Firewall verification complete"
