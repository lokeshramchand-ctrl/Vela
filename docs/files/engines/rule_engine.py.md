# File: `engines/rule_engine.py`

## Purpose
A deterministic, dictionary-driven merchant/category classifier — the Phase 1–2 fallback categorization mechanism.

## Responsibilities
- Load a static alias-to-merchant/category mapping from JSON at startup.
- Pre-compile one regex per alias for fast repeated matching.
- Categorize arbitrary text by scanning for the first matching alias.

## Imports
| Import | Used for |
|---|---|
| `json` | Parsing `merchant_aliases.json` |
| `re` | Building and using the per-alias regex patterns |
| `pathlib.Path` | Resolving the alias file's location relative to this module |
| `logging` | Logging load success/failure |

## Exports
- **`RuleEngine`** — the class (rarely imported directly).
- **`rule_engine`** — the singleton instance, imported by `routers/v1.py`.

## Execution Flow
1. On import, `BASE_DIR` and `ALIASES_FILE` are computed (`Path(__file__).resolve().parent.parent / "merchant_aliases.json"` — i.e., the repo root, since `engines/` is one level below it).
2. `rule_engine = RuleEngine()` runs at the bottom of the file, at import time.
3. `__init__` calls `_load_rules()` (reads and parses the JSON file, or falls back to `{}` if missing) then `_compile_patterns()` (builds `self.compiled_rules`, a dict from compiled regex → `{merchant, category}`).
4. From then on, `categorize(text)` can be called any number of times without repeating the load/compile work.

## Functions (plain English)

### `RuleEngine.__init__(self)`
In simple English: "When this engine is created, immediately load the alias rules from disk and get all the regex patterns ready to use." Runs exactly once, at import time (since `rule_engine` is a module-level singleton).

### `RuleEngine._load_rules(self) -> dict`
In simple English: "Try to open and read the merchant-aliases JSON file. If it's found, parse it into a dictionary. If the file doesn't exist for some reason, don't crash — just log a warning and start with an empty set of rules, meaning nothing will ever match." The leading underscore signals this is meant as an internal helper, not something outside code should call directly.

### `RuleEngine._compile_patterns(self)`
In simple English: "For every alias we loaded (like 'swiggy'), build a search pattern that matches that exact word, ignoring uppercase/lowercase differences, but only when it appears as a whole word (so it wouldn't accidentally match 'swiggystock' as containing 'swiggy'). Do this once now, so we don't have to rebuild these patterns every single time we check a piece of text." Also an internal helper.

### `RuleEngine.categorize(self, text: str) -> dict`
In simple English: "Look through our whole list of ready-made search patterns, one by one, and check whether any of them appear anywhere in the given text. The moment one matches, immediately return that alias's merchant and category, with a fixed high confidence of 0.95 — don't bother checking the rest, even if a later, possibly better, match exists further down the list. If we get through every pattern and nothing matched at all, return 'Unknown'/'Uncategorized' with 0.0 confidence instead." This is the one public method meant to be called from outside the class.

## Classes

### `RuleEngine`
Instance attributes: `self.rules` (raw dict loaded from JSON), `self.compiled_rules` (dict mapping compiled `re.Pattern` objects to `{merchant, category}` dicts). No inheritance beyond the implicit `object`.

## Interfaces
Not applicable formally, though `categorize(text: str) -> dict` is a simple, predictable function contract any caller can rely on regardless of internal implementation.

## Hooks
Not applicable.

## Utilities
`_load_rules` and `_compile_patterns` are effectively private setup utilities, both called only once, from `__init__`.

## Dependencies
`json`, `re`, `pathlib`, `logging` — all Python standard library, no third-party or internal-module dependencies.

## Side Effects
- **Reads a file from disk** at import time (`merchant_aliases.json`) — the only I/O this module performs.
- Logs on both success (`info`) and missing-file fallback (`warning`).
- No writes, no network calls, no mutation of shared state beyond its own instance's attributes.

## Performance Considerations
- Regex pre-compilation at startup (rather than per-call) is the key performance decision here — compiling a regex is relatively expensive, so doing it once for a small, static rule set and reusing the compiled patterns on every `categorize()` call is the correct optimization.
- `categorize()`'s linear scan over `compiled_rules` means cost grows with the number of aliases — for the current 9-entry dictionary this is trivial, but it would become a bottleneck if the alias list grew into the thousands, at which point a more structured lookup (e.g., a trie or Aho-Corasick multi-pattern matcher) would scale better than N independent regex searches per call.
- Dict iteration order in Python 3.7+ is guaranteed to be insertion order, which is why "first match wins" is deterministic and reproducible given a fixed JSON file — but it also means alias ordering in the JSON file silently determines priority when multiple aliases could plausibly match the same text (though with whole-word matching, true overlaps are unlikely with the current data).

## Possible Interview Questions
- "Why pre-compile every regex pattern in `__init__` rather than compiling them lazily on first use?" (The whole rule set is small, static, and known at startup — there's no benefit to deferring the cost, and doing it once avoids paying the compilation cost repeatedly across the life of the process.)
- "What happens if two aliases could both match the same input text?" (Whichever one appears first in `compiled_rules`' iteration order — which mirrors the JSON file's key order — wins; there's no scoring or 'best match' logic, just first-match-wins.)
- "Why does a missing `merchant_aliases.json` file not crash the application?" (`_load_rules` catches `FileNotFoundError` specifically and falls back to an empty rules dict, logging a warning — this is a deliberate 'degrade gracefully' choice, meaning the engine still works, it just never matches anything, rather than taking down the whole app over a missing config file.)
- "How would you extend this to support partial/fuzzy matching instead of exact whole-word matching?" (You'd need to replace the `\b<alias>\b` regex approach with something like a Levenshtein-distance comparison or a fuzzy string-matching library — a meaningfully different architecture, since the current design's speed relies specifically on exact regex matching.)
