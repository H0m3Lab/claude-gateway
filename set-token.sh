#!/bin/bash
# Paste the token printed by `claude setup-token` (run it on any machine with Claude Code).
# The input is hidden, saved to .env as CLAUDE_CODE_OAUTH_TOKEN, and the container is recreated.
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo ".env not found: cp .env.example .env first"; exit 1; }
read -rsp "Paste CLAUDE_CODE_OAUTH_TOKEN: " T; echo
[ ${#T} -gt 20 ] || { echo "too short, nothing changed"; exit 1; }
umask 077
{ grep -v '^CLAUDE_CODE_OAUTH_TOKEN=' .env || true; echo "CLAUDE_CODE_OAUTH_TOKEN=$T"; } > .env.new
mv .env.new .env
docker compose up -d --force-recreate >/dev/null && echo "saved, container recreated"
