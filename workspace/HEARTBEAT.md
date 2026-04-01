# Heartbeat — Periodic Monitoring Tasks

Every time you wake up on a cron trigger, run through this checklist.

## 0. Cron Job Integrity Check

Before doing anything else, verify the cron job that triggered this wake-up still exists and is enabled.

- If the `whale-tracker` job was manually removed or disabled but `memory/watchlist.md` still has entries, clear `memory/watchlist.md` back to its empty template.
- If the `price-monitor` job was manually removed or disabled but `memory/pricelist.md` still has entries, clear `memory/pricelist.md` back to its empty template.
- If either was cleaned up, tell the user: "It looks like the [job name] job was removed outside of our workflow, so I've cleared the tracking list. To set it up again, just ask me. Please don't edit or remove cron jobs manually, just tell me what you'd like to change and I'll handle it."
- If everything checks out, proceed normally.

## 1. Wallet Watchlist Check
- Read `memory/watchlist.md` for tracked wallets
- For each wallet, call `alchemy_getAssetTransfers` with categories `["external", "erc20", "erc721", "erc1155"]` since the last check timestamp
- Filter for significant transfers (above the wallet's threshold in the watchlist)

## 2. Token Price Check
- Read `memory/pricelist.md` for tracked tokens
- Fetch current prices via the Prices API (`/tokens/by-symbol` or `/tokens/by-address`)
- Compare to last recorded prices in memory

## 3. NFT Floor Price Check
- For tracked NFT collections, query the NFT API for current floor prices
- Compare to previous floor prices in memory

## 4. Update Memory
- Update last-check timestamps in watchlist and pricelist
- Update last-known prices for comparison on next run
- Log any significant findings to `memory/YYYY-MM-DD.md`

## 5. Report — CRITICAL RULES

**If nothing exceeded any threshold: produce ZERO output. No message. No summary. No "all clear". No "nothing to report". Literally do not reply. Just update memory and end the turn.**

Only send a message if at least one item crossed its threshold. In that case, report only the items that crossed.
