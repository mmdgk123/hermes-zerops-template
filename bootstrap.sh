#!/bin/bash
# hermes + 9router bootstrap for Zerops nodejs service (non-root safe).
# Secrets come from Zerops service env (dotEnvSecrets):
#   NEW_TG_TOKEN = telegram bot token of the new hermes
#   NEW_TG_CHAT  = telegram chat id allowed
#   ROUTER_URL    = user's own 9router base URL (https://....zerops.app/v1)
#   ROUTER_KEY    = its API key. Fully independent per install — no shared infra.
set -x
export HERMES_HOME=/home/zerops/.hermes
export PATH="$HOME/.local/bin:/opt/zerops/bin:$PATH"

# 9router install happens HERE (not initCommands — those run parallel with start).
# idempotent: skip if already installed and working.
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
# Router: user's OWN 9router service (ROUTER_URL + ROUTER_KEY), fully independent.
# Falls back to the free opencode-zen model when no router is given.
if [ -n "$ROUTER_URL" ] && [ -n "$ROUTER_KEY" ]; then
  hermes config set model.base_url "$ROUTER_URL" 2>/dev/null || true
  hermes config set model.api_key "$ROUTER_KEY" 2>/dev/null || true
  hermes config set model.default "oc/muse-spark-1.3-contributor-free" 2>/dev/null || true
  set_kv CUSTOM_API_KEY "$ROUTER_KEY"
else
  hermes config set model.default "oc/muse-spark-1.3-contributor-free" 2>/dev/null || true
  set_kv OPENCODE_ZEN_API_KEY "oc_sk_f70267f06abb_w_xXuLT4OJn3Fvxo6jwLLtf9at5-MC2i"
fi

# No local 9router anymore — hermes talks to the router service (or free model).
nohup hermes gateway run > /home/zerops/gateway.log 2>&1 &
echo "bootstrap done, services starting..."
wait
