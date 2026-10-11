#!/bin/bash
# hermes + FCC bootstrap for Zerops nodejs service (non-root safe).
# Secrets come from Zerops service env (dotEnvSecrets):
#   NEW_TG_TOKEN = telegram bot token of the new hermes
#   NEW_TG_CHAT  = telegram chat id allowed
#   FCC_URL      = FCC proxy base URL (https://....zerops.app/v1)
#   FCC_KEY      = FCC proxy auth token. Fully independent per install — no shared infra.
set -x
export HERMES_HOME=/home/zerops/.hermes
export PATH="$HOME/.local/bin:/opt/zerops/bin:$PATH"

# hermes (user install, no root needed)
if ! command -v hermes >/dev/null 2>&1; then
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | \
    bash -s -- --non-interactive --skip-browser --skip-computer-use || true
fi
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HERMES_HOME"
ENVF="$HERMES_HOME/.env"
touch "$ENVF"
set_kv() { grep -q "^$1=" "$ENVF" 2>/dev/null && sed -i "s|^$1=.*|$1=$2|" "$ENVF" || echo "$1=$2" >> "$ENVF"; }
set_kv TELEGRAM_BOT_TOKEN "$NEW_TG_TOKEN"
set_kv TELEGRAM_ALLOWED_USERS "$NEW_TG_CHAT"
set_kv TELEGRAM_HOME_CHANNEL "$NEW_TG_CHAT"
[ -n "$FCC_KEY" ] && set_kv CUSTOM_API_KEY "$FCC_KEY"
chmod 600 "$ENVF" || true

if [ -z "$FCC_URL" ] || [ -z "$FCC_KEY" ]; then
  echo "ERROR: FCC_URL/FCC_KEY missing — FCC proxy URL and token are required." >&2
  exit 1
fi
# FCC serves /v1/responses (codex_responses wire), not /v1/chat/completions.
# Register it as a user provider with transport codex_responses.
hermes config set providers.fcc.api "$FCC_URL" 2>/dev/null || true
hermes config set providers.fcc.transport codex_responses 2>/dev/null || true
hermes config set providers.fcc.key_env CUSTOM_API_KEY 2>/dev/null || true
hermes config set model.provider "custom:fcc" 2>/dev/null || true
hermes config set model.base_url "$FCC_URL" 2>/dev/null || true
hermes config set model.api_key "$FCC_KEY" 2>/dev/null || true
hermes config set model.api_mode codex_responses 2>/dev/null || true
hermes config set model.default "gemini/models/gemini-3.1-flash-lite" 2>/dev/null || true
set_kv CUSTOM_API_KEY "$FCC_KEY"

# hermes talks to the FCC proxy service.
nohup hermes gateway run > /home/zerops/gateway.log 2>&1 &
echo "bootstrap done, services starting..."
wait
