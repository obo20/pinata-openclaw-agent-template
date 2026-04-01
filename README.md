# Alchemy Agent — On-Chain Intelligence

An OpenClaw agent template powered by Alchemy, built for deployment on [Pinata](https://agents.pinata.cloud).

Alchemy Agent turns Alchemy's blockchain APIs into a conversational intelligence layer. Ask questions about any wallet, track whale movements, and monitor token prices — all from chat.

## What It Does

### 1. Wallet Intelligence
Ask about any wallet and get a full multi-chain profile.

> "Show me vitalik.eth's portfolio"

Returns: token balances, NFT holdings, recent transfers, and total portfolio value across all Alchemy-supported chains.

### 2. Smart Money Tracking
Watch wallets for significant activity. Runs automatically every 15 minutes.

> "Watch this VC wallet for moves: 0xABC..."

Monitors: large token transfers, NFT acquisitions, new positions, and notable outflows. Alerts you when something happens.

### 3. Token & NFT Price Monitoring
Track prices and get alerts on big moves. Runs automatically every 15 minutes.

> "Track ETH and BAYC prices, alert me on 5% swings"

Monitors: token spot prices and NFT collection floor prices. Alerts when changes exceed your threshold.

## Quick Start

### Deploy on Pinata
1. Go to [agents.pinata.cloud](https://agents.pinata.cloud) and deploy this template
2. Set your `ALCHEMY_API_KEY` — get one free at [dashboard.alchemy.com](https://dashboard.alchemy.com)
3. Set an LLM provider key: `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`
4. Start chatting

### Run Locally with OpenClaw
```bash
git clone <this-repo>
cd pinata-agents
./setup.sh
```

The setup script will:
- Prompt for your Alchemy API key and LLM provider key (Anthropic or OpenAI)
- Test the Alchemy API connection
- Register the agent workspace with OpenClaw
- Start the gateway

Or do it manually:
```bash
cp .env.example .env
# Fill in your API keys in .env
openclaw agents add alchemy-agent --workspace ./workspace
openclaw gateway
```

## Alchemy APIs Used

| API | What It Does |
| --- | --- |
| **Token API** | Token balances, metadata, allowances |
| **NFT API** | NFT ownership, metadata, floor prices, spam detection |
| **Transfers API** | Transfer history with category filters |
| **Prices API** | Spot and historical token prices |
| **Portfolio API** | Multi-chain portfolio aggregation |
| **JSON-RPC** | Standard EVM methods (eth_getBalance, eth_blockNumber, etc.) |

## Supported Chains

Works across ~100 chains Alchemy supports, including:

Ethereum, Base, Polygon, Arbitrum, Optimism, ZKsync, Scroll, Linea, Blast, Avalanche, BNB Chain, Shape, Solana, and more.

See the [full list](https://www.alchemy.com/docs/reference/node-supported-chains).

## Customization

Edit `workspace/USER.md` to configure:
- Wallets to track
- Tokens and NFT collections to monitor
- Alert thresholds
- Preferred chains

## Scheduled Tasks

Two pre-configured tasks run every 15 minutes (defined in `manifest.json`):

| Task | What It Does |
| --- | --- |
| `whale-tracker` | Checks watchlist wallets for new transfer activity |
| `price-monitor` | Checks tracked token/NFT prices for significant moves |

Edit the `tasks` array in `manifest.json` to adjust schedules or add new tasks.

## File Structure

```
├── manifest.json         # Agent config (name, secrets, tasks, template metadata)
├── setup.sh              # One-command local setup (prompts for keys, starts gateway)
├── .env.example          # Template env vars
├── openclaw.json         # OpenClaw gateway configuration (for local dev)
├── cron/
│   └── jobs.json         # OpenClaw cron store (for local dev)
└── workspace/            # Agent workspace (mounted at runtime)
    ├── AGENTS.md         # Operating rules and workflows
    ├── SOUL.md           # Agent personality
    ├── BOOT.md           # First-run setup checklist
    ├── HEARTBEAT.md      # Periodic monitoring tasks
    ├── IDENTITY.md       # Agent name and branding
    ├── USER.md           # Your preferences (customize this)
    ├── TOOLS.md          # Environment-specific notes
    ├── skills/
    │   └── alchemy-api/  # Alchemy API skill with 82 reference docs
    └── memory/           # Runtime state (watchlists, price logs, daily reports)
```

## Requirements

- **Alchemy API Key** — Free tier works. [Get one here](https://dashboard.alchemy.com).
- **LLM Provider API Key** — Either [Anthropic](https://console.anthropic.com) or [OpenAI](https://platform.openai.com/api-keys).
- **OpenClaw** — Included with Pinata deployment, or [install locally](https://openclaw.dev).
