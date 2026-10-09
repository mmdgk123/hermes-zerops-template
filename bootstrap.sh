#!/bin/bash
# hermes + 9router bootstrap for Zerops nodejs service (non-root safe).
# Secrets come from Zerops service env (dotEnvSecrets):
#   NEW_TG_TOKEN = telegram bot token of the new hermes
#   NEW_TG_CHAT  = telegram chat id allowed
#   ROUTER_KEY   = 9router API key (optional, empty = free providers only)
set -x
export HERMES_HOME=/home/zerops/.hermes
export PATH="$HOME/.local/bin:/opt/zerops/bin:$PATH"

# 9router (idempotent: skip if already installed and working)
export PATH="$HOME/.local/bin:$PATH"
if ! command -v 9router >/dev/null 2>&1; then
  rm -rf "$HOME/.local/lib/node_modules/9router" "$HOME/.local/bin/9router" 2>/dev/null || true
  npm install --prefix "$HOME/.local" -g 9router || true
fi

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
[ -n "$ROUTER_KEY" ] && set_kv CUSTOM_API_KEY "$ROUTER_KEY"
chmod 600 "$ENVF" || true

hermes config set model.provider custom 2>/dev/null || true
# 9router runs on the shared router service (local 9router is flaky on zerops);
# point hermes directly at it. ROUTER_KEY = the shared router API key.
if [ -n "$ROUTER_KEY" ]; then
  hermes config set model.base_url "https://router-3321-20127.prg1.zerops.app/v1" 2>/dev/null || true
  set_kv CUSTOM_API_KEY "$ROUTER_KEY"
else
  hermes config set model.base_url "http://127.0.0.1:20128/v1" 2>/dev/null || true
fi

export PORT=20128 HOSTNAME=0.0.0.0 DATA_DIR=/home/zerops/.9router \
  NEXT_PUBLIC_BASE_URL="http://127.0.0.1:20128" INITIAL_PASSWORD=123456
if [ -n "$ROUTER_KEY" ]; then
  echo "using shared 9router, skipping local install"
else
  if command -v 9router >/dev/null 2>&1; then
    nohup 9router --no-browser --port 20128 > /home/zerops/9router.log 2>&1 &
    # wait for 9router API before starting gateway (model needs it)
    for i in $(seq 1 30); do
      sleep 5
      if curl -sf --max-time 5 http://127.0.0.1:20128/v1/models >/dev/null 2>&1; then
        echo "9router ready"
        break
      fi
    done
  else
    echo "WARNING: 9router not installed, gateway will use free default model"
  fi
fi
nohup hermes gateway run > /home/zerops/gateway.log 2>&1 &
echo "bootstrap done, services starting..."
wait
