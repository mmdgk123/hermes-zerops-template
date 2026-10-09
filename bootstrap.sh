#!/bin/bash
# hermes + 9router bootstrap for Zerops nodejs service (non-root safe).
# Secrets come from Zerops service env (dotEnvSecrets):
#   NEW_TG_TOKEN = telegram bot token of the new hermes
#   NEW_TG_CHAT  = telegram chat id allowed
#   ROUTER_KEY   = 9router API key (optional, empty = free providers only)
set -x
export HERMES_HOME=/home/zerops/.hermes
export PATH="$HOME/.local/bin:/opt/zerops/bin:$PATH"

# 9router (npm global; on zerops nodejs base npm is available user-wide)
npm install -g 9router || npm install --prefix "$HOME/.local" -g 9router || true
export PATH="$HOME/.local/bin:$PATH"

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
set_kv TELEGRAM_HOME_CHANNEL "$NEW_TG_CHAT"
[ -n "$ROUTER_KEY" ] && set_kv CUSTOM_API_KEY "$ROUTER_KEY"
chmod 600 "$ENVF" || true

hermes config set model.provider custom 2>/dev/null || true
hermes config set model.base_url "http://127.0.0.1:20128/v1" 2>/dev/null || true

export PORT=20128 HOSTNAME=0.0.0.0 DATA_DIR=/home/zerops/.9router \
  NEXT_PUBLIC_BASE_URL="http://127.0.0.1:20128" INITIAL_PASSWORD=123456
nohup 9router --no-browser --port 20128 > /home/zerops/9router.log 2>&1 &
sleep 5
nohup hermes gateway run > /home/zerops/gateway.log 2>&1 &
echo "bootstrap done, services starting..."
wait
