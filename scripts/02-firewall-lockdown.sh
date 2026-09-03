#!/usr/bin/env bash
# Run once on the server. Locks down public access to SSH only.
# VaultAI ports are already bound to 127.0.0.1 in docker-compose.yml,
# so this is a second, independent layer — belt and suspenders.
#
# IMPORTANT: run this over a console/VNC session if possible, or keep
# a second SSH session open while testing, in case of a lockout mistake.
set -euo pipefail

echo "== VaultAI firewall lockdown =="

if ! command -v ufw >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y ufw
fi

# Default deny everything inbound, allow everything outbound
ufw default deny incoming
ufw default allow outgoing

# Allow SSH — rate-limited to slow down brute force
ufw limit 22/tcp comment "SSH"

# Explicitly do NOT open 8081/8082/9091/3001 — they stay bound to
# 127.0.0.1 by docker-compose and are never touched by ufw rules,
# which only govern the public interface anyway.

ufw --force enable
ufw status verbose

echo ""
echo "Lockdown complete. Only SSH (22) is reachable from the internet."
echo "Everything else is either firewalled or bound to 127.0.0.1 only."
