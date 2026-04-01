#!/usr/bin/env bash
set -euo pipefail

# ─── Alchemy Agent — Template Setup ─────────────────────────────────────
# This script:
#   1. Checks for openclaw CLI
#   2. Prompts for required API keys
#   3. Writes .env
#   4. Registers the workspace as an openclaw agent
#   5. Starts the gateway

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "⚗️  Alchemy Agent — On-Chain Intelligence"
echo "   Powered by Alchemy × OpenClaw"
echo "───────────────────────────────────────────"
echo ""

# ── 0. Ensure correct Node version (nvm) ──────────────────────────────
REQUIRED_NODE_MAJOR=22
REQUIRED_NODE_MINOR=16
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
  . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  CURRENT_MAJOR=$(node -e "process.stdout.write(String(process.versions.node.split('.')[0]))" 2>/dev/null || echo "0")
  CURRENT_MINOR=$(node -e "process.stdout.write(String(process.versions.node.split('.')[1]))" 2>/dev/null || echo "0")
  if [ "$CURRENT_MAJOR" -lt "$REQUIRED_NODE_MAJOR" ] || \
     { [ "$CURRENT_MAJOR" -eq "$REQUIRED_NODE_MAJOR" ] && [ "$CURRENT_MINOR" -lt "$REQUIRED_NODE_MINOR" ]; }; then
    echo "Node >= $REQUIRED_NODE_MAJOR.$REQUIRED_NODE_MINOR.0 required (found $CURRENT_MAJOR.$CURRENT_MINOR). Switching via nvm..."
    nvm use "$REQUIRED_NODE_MAJOR" 2>/dev/null || {
      echo "Installing Node $REQUIRED_NODE_MAJOR via nvm..."
      nvm install "$REQUIRED_NODE_MAJOR"
    }
  fi
fi

# ── 1. Check for openclaw ────────────────────────────────────────────────
if ! command -v openclaw &>/dev/null; then
  echo "❌ openclaw CLI not found."
  echo "   Install it from https://docs.openclaw.ai/cli or deploy on https://agents.pinata.cloud"
  exit 1
fi

echo "✓ openclaw $(openclaw --version 2>/dev/null || echo '(unknown version)') found"
echo ""

# ── 2. Collect API keys ─────────────────────────────────────────────────
if [ -f .env ]; then
  echo "Found existing .env file."
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
fi

# Alchemy API key
if [ -z "${ALCHEMY_API_KEY:-}" ]; then
  echo "Get a free Alchemy API key at: https://dashboard.alchemy.com"
  read -rp "Enter your ALCHEMY_API_KEY: " ALCHEMY_API_KEY
  if [ -z "$ALCHEMY_API_KEY" ]; then
    echo "❌ Alchemy API key is required."
    exit 1
  fi
else
  echo "✓ ALCHEMY_API_KEY already set"
fi

# LLM provider API key (need at least one)
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "✓ ANTHROPIC_API_KEY already set"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "✓ OPENAI_API_KEY already set"
else
  echo ""
  echo "You need at least one LLM provider API key."
  echo "  1) Anthropic (https://console.anthropic.com)"
  echo "  2) OpenAI (https://platform.openai.com/api-keys)"
  echo ""
  read -rp "Which provider? [1/2]: " LLM_CHOICE
  if [ "$LLM_CHOICE" = "2" ]; then
    read -rp "Enter your OPENAI_API_KEY: " OPENAI_API_KEY
    if [ -z "$OPENAI_API_KEY" ]; then
      echo "❌ An LLM API key is required."
      exit 1
    fi
  else
    read -rp "Enter your ANTHROPIC_API_KEY: " ANTHROPIC_API_KEY
    if [ -z "$ANTHROPIC_API_KEY" ]; then
      echo "❌ An LLM API key is required."
      exit 1
    fi
  fi
fi

# ── 3. Write .env (only if missing or incomplete) ─────────────────────
ENV_CHANGED=false
if [ ! -f .env ]; then
  ENV_CHANGED=true
elif ! grep -q "ALCHEMY_API_KEY=" .env; then
  ENV_CHANGED=true
elif [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  ENV_CHANGED=true
fi

if [ "$ENV_CHANGED" = true ]; then
  {
    printf '# Required: Alchemy API key\nALCHEMY_API_KEY=%s\n' "$ALCHEMY_API_KEY"
    printf '\n# LLM provider API key (at least one required)\n'
    printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY:-}"
    printf 'OPENAI_API_KEY=%s\n' "${OPENAI_API_KEY:-}"
  } > .env
  echo ""
  echo "✓ .env written"
else
  echo ""
  echo "✓ .env already configured"
fi

# ── 4. Test Alchemy connection ───────────────────────────────────────────
echo ""
echo "Testing Alchemy API connection..."

RESPONSE=$(curl -s -w "\n%{http_code}" "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q '"result"'; then
  BLOCK_HEX=$(echo "$BODY" | sed 's/.*"result":"\(0x[0-9a-fA-F]*\)".*/\1/')
  BLOCK_DEC=$((BLOCK_HEX))
  echo "✓ Connected to Ethereum mainnet (latest block: $BLOCK_DEC)"
else
  echo "❌ Alchemy API test failed (HTTP $HTTP_CODE)"
  echo "   Response: $BODY"
  echo "   Check your API key and try again."
  exit 1
fi

# ── 5. Create memory directory ───────────────────────────────────────────
mkdir -p workspace/memory

# ── 6. Set model based on LLM provider ─────────────────────────────────
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  openclaw config set agents.defaults.model "anthropic/claude-opus-4-6" 2>/dev/null
  echo "✓ Model set to anthropic/claude-opus-4-6"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  openclaw config set agents.defaults.model "openai/gpt-4o" 2>/dev/null
  echo "✓ Model set to openai/gpt-4o"
fi

# ── 7. Register as openclaw agent ────────────────────────────────────────
echo ""
echo "Setting up openclaw agent workspace..."

# Check if agent already exists
if openclaw agents list 2>&1 | grep -q "alchemy-agent"; then
  echo "✓ Agent 'alchemy-agent' already registered"
else
  openclaw agents add alchemy-agent \
    --workspace "$SCRIPT_DIR/workspace" \
    --non-interactive \
    2>&1 || {
      echo ""
      echo "⚠ Could not auto-register agent. You can do it manually:"
      echo "   openclaw agents add alchemy-agent --workspace $SCRIPT_DIR/workspace"
    }
fi

# ── 8. Start the gateway ────────────────────────────────────────────────
echo ""
echo "───────────────────────────────────────────"
echo "✓ Setup complete!"
echo ""
echo "Alchemy Agent is ready. Starting the gateway..."
echo "  • Ask: \"Show me vitalik.eth's portfolio\""
echo "  • Ask: \"Watch 0x... for whale moves\""
echo "  • Ask: \"Track ETH and BAYC prices\""
echo ""
echo "Press Ctrl+C to stop."
echo "───────────────────────────────────────────"
echo ""

# Export keys so the gateway process can see them
export ALCHEMY_API_KEY
[ -n "${ANTHROPIC_API_KEY:-}" ] && export ANTHROPIC_API_KEY
[ -n "${OPENAI_API_KEY:-}" ] && export OPENAI_API_KEY

exec openclaw gateway --force
