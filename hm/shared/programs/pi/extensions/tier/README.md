# Model Tiers

Named model configurations live in `$PI_CODING_AGENT_DIR/tiers.json`:

```json
{
  "economy": {
    "provider": "provider-name",
    "model": "model-id",
    "thinkingLevel": "low"
  }
}
```

Select a tier when starting Pi:

```text
pi --tier economy
```

`--tier` cannot be combined with `--provider`, `--model`, or `--thinking`.
Tier names are dynamic: every valid top-level entry in `tiers.json` is available.

Inside a session:

```text
/tier
/tier performance
```

`/tier` reports the matching current tier and available names. `/tier NAME`
switches the model and thinking level for the current idle session only. It does
not rewrite settings or `tiers.json`.
