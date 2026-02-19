---
name: country-validation
description: >
  Validates raw Country of Origin (COO) data against the official PlanetFWD list of
  acceptable country names, and produces an annotated mapping spreadsheet for audit.

  Use this skill whenever the user mentions: validating countries, country of origin,
  COO data, PlanetFWD country list, mapping raw country names, cleaning country data,
  or preparing COO data for PlanetFWD upload. Trigger even if the user says something
  casual like "clean up my country column", "figure out which countries are valid",
  or "validate my COO spreadsheet".
---

# Country Validation (PlanetFWD)

## What This Skill Does

This skill validates raw Country of Origin (COO) data against PlanetFWD's official
accepted country list. It takes a spreadsheet or data column containing messy, informal,
or mixed-format country names and produces a clean annotated mapping showing:

- The original raw value
- The first country parsed (when multiple countries appear in one cell)
- The validated PlanetFWD-accepted COO value (or "Unknown" if no match)
- The match method used (for full audit traceability)

---

## Skill Assets

All assets live in `/sessions/busy-laughing-bell/mnt/.claude/skills/country_validation/`

| Path | Description |
|------|-------------|
| `assets/valid_countries.json` | Full PlanetFWD valid COO list — 747 entries (full names, 2-letter ISO, 3-letter ISO, "Unknown") |
| `assets/aliases.json` | Curated informal→official mappings (e.g. "Vietnam" → "Viet Nam", "Russia" → "Russian Federation") |
| `scripts/validate_coo.py` | Python validation script — the main execution engine |
| `references/methodology.md` | Full audit methodology documentation |

---

## Workflow

### Step 1 — Ask about output preference

Before doing anything else, ask the user which output format they want:

> "How would you like the output?
> - **Mapping table (default):** A deduplicated list of unique country name mappings only — one row per unique raw value. Best for reviewing and auditing the mapping logic.
> - **Full dataset:** Your original data with all columns kept, plus three new columns appended on the right (First Country Parsed, Validated COO, Match Method). Best when you want the validated values alongside every original row."

Use `--mode mapping` (default) or `--mode full` based on their answer.
If the user doesn't specify or says "default", use `mapping`.

### Step 2 — Identify the input

Ask (or infer from context) which file and column contains the raw COO data.
Common column names: "Country of Origin", "COO", "Raw Country Of Origin", "Country".

### Step 3 — Run the validation script

```bash
pip install openpyxl pandas --break-system-packages -q

python3 /sessions/busy-laughing-bell/mnt/.claude/skills/country_validation/scripts/validate_coo.py \
  "<input_file_path>" \
  --col "<column_name>" \
  --sheet "<sheet_name_if_needed>" \
  --output "<output_file_path>" \
  --mode mapping \
  --skill-dir "/sessions/busy-laughing-bell/mnt/.claude/skills/country_validation"
```

Replace `--mode mapping` with `--mode full` if the user chose the full dataset option.

Always pass `--skill-dir` explicitly so the script can locate `valid_countries.json` and `aliases.json`.

If the column name contains "country", "coo", or "origin", `--col` can be omitted (auto-detected).
For CSV files, omit `--sheet`.

### Step 4 — Report the summary

The script prints a validation summary. Always relay this to the user:
- Total unique raw values
- Count and % successfully matched
- Count and % mapped to "Unknown"
- Breakdown by match method
- List of values that ended up as "Unknown"

### Step 5 — Present the output file

Save to the workspace folder and provide a `computer://` link so the user can open it directly.

---

## Matching Logic (Priority Order)

Each raw COO value is resolved using this exact sequence:

1. **Null / empty** → `"Unknown"` (method: `null`)

2. **Multi-country string** — if a value contains commas or slashes, extract only the first segment before the first delimiter, then continue matching on that first value
   - `"USA, Canada, Mexico"` → match `"USA"`
   - `"Asia, Central America"` → match `"Asia"` → caught by Step 3

3. **Regional / continental term** → `"Unknown"` (method: `regional`)
   - Asia, Africa, Europe, South America, Central America, North America, Middle East, Oceania, Global, Various, N/A, None, Unknown, Unspecified, etc.

4. **Exact match** (case-insensitive) against the 747-entry valid list → return the correctly-cased valid name (method: `exact`)

5. **Alias lookup** — check `aliases.json` for common informal/abbreviated names (method: `alias`)
   - "Vietnam" → "Viet Nam"
   - "Russia" → "Russian Federation"
   - "UK" → "United Kingdom"
   - "Turkey" → "Türkiye"
   - "Ivory Coast" → "Côte d'Ivoire"
   - "Czech Republic" → "Czechia"
   - "Burma" → "Myanmar"

6. **Normalised match** — strip common prefixes ("The", "Republic of", "Islamic Republic of") and try again (method: `normalised`)

7. **No match** → `"Unknown"` (method: `no_match`) — flag these for the user's manual review

---

## Output Format

One row per **unique** raw COO value (deduplicated), saved as `.xlsx`:

| Column | Description |
|--------|-------------|
| `Raw Country of Origin` | The original raw value, exactly as input |
| `First Country Parsed` | First country extracted from multi-country strings |
| `Validated COO (PlanetFWD)` | PlanetFWD-accepted value, or "Unknown" |
| `Match Method` | `exact` / `alias` / `normalised` / `regional` / `null` / `no_match` |

Colour coding in the output spreadsheet:
- **Green** = successfully matched to a valid country
- **Amber** = mapped to "Unknown" (worth reviewing)
- **Red** = `no_match` — unrecognised, needs manual fix

---

## Common Edge Cases

**"USA" vs "United States"**: Both are present in the valid list (ISO-3 code and full name respectively). The script returns whichever one the raw data contains if it's a direct exact match.

**"Vietnam"**: Mapped via alias to "Viet Nam" — PlanetFWD's official spelling.

**"Russia"**: Mapped via alias to "Russian Federation".

**Multi-country strings like "Asia, Central America"**: The first segment "Asia" is a regional term → "Unknown". This is correct behaviour; these values genuinely cannot be attributed to one country.

**`no_match` values**: These are raw values not in the valid list and not covered by any alias. Tell the user to either add a mapping to `aliases.json` or correct the source data manually.

---

## Adding New Aliases

When a raw country name consistently appears but isn't matched, extend `aliases.json`:

```json
{
  "south vietnam": "Viet Nam",
  "your_informal_name": "Exact PlanetFWD Valid Name"
}
```

Keys must be lowercase. Values must exactly match an entry in `valid_countries.json`.

---

## Audit Reference

For the complete methodology, data lineage, and validation rules used in this skill,
read: `references/methodology.md`
