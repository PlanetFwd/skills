# Country of Origin Validation — Methodology Documentation

**Skill:** `country_validation`
**Organization:** PlanetFWD
**Purpose:** Audit-grade documentation of the methodology used to validate raw Country of Origin (COO) data against the PlanetFWD platform's accepted country list.

---

## 1. Purpose and Scope

PlanetFWD's emissions platform requires that every purchase record includes a Country of Origin value drawn from a controlled vocabulary — the "valid COO list". Raw data supplied by clients often contains country names in formats that do not match this list: informal names, ISO codes, abbreviations, multiple countries in a single field, regional terms, or missing values.

This skill provides a deterministic, auditable, and repeatable process for mapping raw COO values to their PlanetFWD-accepted equivalents.

**In scope:** Raw text strings representing country or region names in any format.
**Out of scope:** Country validation via geographic coordinates, postal codes, or phone prefixes.

---

## 2. Data Sources

### 2.1 Valid COO List

**Source file:** `coo_data.xlsx`, sheet `valid coo`
**Extracted to:** `assets/valid_countries.json`
**Entry count:** 747 entries (as of initial skill creation)

The valid COO list contains three types of entries:

| Type | Example | Description |
|------|---------|-------------|
| Full country name | `"United States"`, `"Viet Nam"` | ISO 3166-1 standard names used in the PlanetFWD platform UI |
| 2-letter ISO code | `"US"`, `"VN"` | ISO 3166-1 alpha-2 codes |
| 3-letter ISO code | `"USA"`, `"VNM"` | ISO 3166-1 alpha-3 codes |
| Special value | `"Unknown"` | Reserved for records where COO cannot be determined |

All three formats are valid inputs to the PlanetFWD upload template. The skill preserves the user's format when an exact match is found.

### 2.2 Alias Mapping

**Source:** Expert curation based on observed raw data patterns
**Location:** `assets/aliases.json`
**Entry count:** 66 aliases (as of initial skill creation)

The alias mapping covers common informal names, regional names that correspond to a single country, historical names, and abbreviations not present in the valid COO list. All aliases were sourced from:

- Analysis of the 80 unique raw COO values observed in `coo_data.xlsx`
- Widely recognised alternative country names in English
- ISO 3166 retired names

Examples:

| Raw Alias | Valid PlanetFWD COO | Rationale |
|-----------|---------------------|-----------|
| `Vietnam` | `Viet Nam` | PlanetFWD uses the ISO-standard diacritical spelling |
| `Russia` | `Russian Federation` | Common informal short-form |
| `UK` | `United Kingdom` | Standard abbreviation |
| `Turkey` | `Türkiye` | Official name change (2022) |
| `Ivory Coast` | `Côte d'Ivoire` | English common name → French official name |
| `Czech Republic` | `Czechia` | Short-form adopted by UN (2016) |
| `Burma` | `Myanmar` | Name changed; both still in common use |
| `South Korea` | `Korea, Republic of` | ISO 3166 formal name |

### 2.3 Regional Terms List

**Defined in:** `scripts/validate_coo.py` (`REGIONAL_TERMS` set)

These terms represent geographic regions rather than sovereign states and cannot be matched to any single PlanetFWD country entry. They are deterministically mapped to `"Unknown"`:

Asia, Africa, Europe, South America, North America, Central America, Middle East, Oceania, Caribbean, West Africa, East Africa, Southeast Asia, South Asia, North Africa, Sub-Saharan Africa, Latin America, Global, Worldwide, International, Various, Multiple, Unknown, Other, N/A, NA, None, Not Applicable, Not Specified, Unspecified.

---

## 3. Validation Algorithm

### 3.1 Pre-processing

Before matching, all raw values are normalised for comparison by:
- Stripping leading and trailing whitespace
- Converting to lowercase for case-insensitive matching
- Retaining the original value for output display

### 3.2 Multi-Country Parsing

Many raw COO fields contain multiple countries in a single cell, delimited by commas, semicolons, or slashes (e.g. `"USA, Canada, Mexico"`). The matching algorithm extracts only the **first** listed country as the representative COO value for that record.

**Rationale:** This follows PlanetFWD's internal convention as evidenced in the reference dataset (`coo_data.xlsx`), where the column `First Country` consistently takes the first value from comma-separated strings. The first-listed country is assumed to be the primary source country.

**Implication:** For records where COO is genuinely ambiguous across multiple countries, the output will reflect only the first listed country. Users who require a different treatment should pre-clean their data before validation.

### 3.3 Matching Priority Chain

Each raw value (or its extracted first-country fragment) is resolved through the following ordered steps. The first step to produce a match is used; subsequent steps are not attempted.

**Step 1 — Null / Empty**
If the raw value is null, NaN, or an empty string after stripping, the result is `"Unknown"` with match method `null`. This represents genuine missing data.

**Step 2 — Regional Term Check**
The normalised value is checked against the `REGIONAL_TERMS` set. If it matches, the result is `"Unknown"` with match method `regional`. Regional terms are not treated as errors — they represent valid supplier-side entries that cannot be attributed to a specific country.

**Step 3 — Exact Match**
The normalised value is compared (case-insensitively) against the full 747-entry valid COO list. If matched, the correctly-cased original valid name is returned with method `exact`. This is the most reliable match type.

**Step 4 — Alias Lookup**
The normalised value is looked up in `aliases.json`. If a mapping exists, the target valid COO string is returned with method `alias`. Alias matches are reliable but depend on the completeness of the alias dictionary.

**Step 5 — Normalised Match**
Common prefixes are stripped (`"the "`, `"republic of "`, `"islamic republic of "`, `"democratic "`, `"people's "`, `"federated states of "`), and the shortened form is re-attempted against both the valid list (Step 3) and the alias dictionary (Step 4). If matched, method is `normalised`.

**Step 6 — No Match**
If none of the above steps produce a match, the result is `"Unknown"` with method `no_match`. This indicates a value that is not in the valid list, not a known alias, and not a recognised regional term. These should be reviewed manually.

### 3.4 Priority Logic Summary

```
raw_value
  └─ null/empty?         → "Unknown" (null)
  └─ multi-country?      → take first segment, continue
  └─ regional term?      → "Unknown" (regional)
  └─ exact match?        → valid_name (exact)
  └─ in aliases.json?    → valid_name (alias)
  └─ normalised match?   → valid_name (normalised)
  └─ no match            → "Unknown" (no_match)
```

---

## 4. Output Specification

### 4.1 Deduplication

The output contains one row per **unique** raw COO value. This is intentional: the validation mapping is a reference table, not a row-level annotation of the original data. To apply validated values back to the full dataset, join on the `Raw Country of Origin` column.

### 4.2 Columns

| Column | Type | Description |
|--------|------|-------------|
| `Raw Country of Origin` | String / null | The original raw value, preserved exactly |
| `First Country Parsed` | String / null | First country extracted from multi-country strings; equal to raw value for single-country entries |
| `Validated COO (PlanetFWD)` | String | The PlanetFWD-accepted value, or `"Unknown"` |
| `Match Method` | String | One of: `exact`, `alias`, `normalised`, `regional`, `null`, `no_match` |

### 4.3 Sort Order

Rows are sorted: successfully matched entries (non-Unknown) first, alphabetically; then "Unknown" entries, alphabetically by raw value.

### 4.4 Visual Indicators

The output spreadsheet uses colour coding for quick visual review:
- Dark blue header row
- Green rows: `Validated COO` is a real country (matched)
- Amber rows: `Validated COO` is "Unknown" (matched to unknown or regional)
- Red cell in Match Method: `no_match` (unrecognised value, needs manual review)

---

## 5. Validation Against Ground Truth

The algorithm was validated against 4,851 rows of labelled data from `coo_data.xlsx` (sheet: `example raw coo data`), which contains a pre-existing `valid country` column mapped by PlanetFWD.

**Result: 0 mismatches** — the algorithm reproduced the ground-truth mapping exactly across all 80 unique raw values present in the dataset.

Match method breakdown on validation run (81 unique values including NaN):

| Method | Count | Notes |
|--------|-------|-------|
| `exact` | 66 | Direct case-insensitive match to valid list |
| `regional` | 11 | Continental/regional terms correctly sent to "Unknown" |
| `alias` | 3 | "Vietnam"→"Viet Nam", "Russia"→"Russian Federation" (×2 with "Russia, Norway") |
| `null` | 1 | NaN / missing value |

---

## 6. Limitations

**Single-country assumption:** Multi-country strings are resolved to the first listed country. This may not represent the actual primary origin for all records.

**Alias coverage:** The alias dictionary covers 66 known informal names. New informal names encountered in future datasets will fall through to `no_match` until added to `aliases.json`.

**No fuzzy matching:** The algorithm does not use fuzzy string matching (e.g. Levenshtein distance). This is a deliberate design choice to ensure determinism and auditability — every match is traceable to a specific rule. Fuzzy matching introduces ambiguity that is hard to audit.

**Language coverage:** The alias dictionary is English-centric. Country names in other languages (e.g. `"Allemagne"` for Germany, `"Japon"` for Japan) will produce `no_match` unless added to `aliases.json`.

**Valid list version:** The valid COO list was extracted from `coo_data.xlsx` at skill creation time. If PlanetFWD updates its accepted country list, `assets/valid_countries.json` must be regenerated from the updated source.

---

## 7. Maintenance Procedures

### Updating the valid country list

Re-extract from the current `coo_data.xlsx`:
```bash
python3 -c "
import pandas as pd, json
df = pd.read_excel('coo_data.xlsx', sheet_name='valid coo')
valid = [v for v in df['countryOfOrgin'].tolist() if isinstance(v, str)]
with open('assets/valid_countries.json', 'w', encoding='utf-8') as f:
    json.dump(valid, f, ensure_ascii=False, indent=2)
print(f'Written {len(valid)} entries')
"
```

### Adding a new alias

Edit `assets/aliases.json`. Keys must be lowercase; values must exactly match an entry in `valid_countries.json`.

### Handling a new regional term

Add it to the `REGIONAL_TERMS` set in `scripts/validate_coo.py` (line ~30).

---

## 8. File Inventory

```
country_validation/
├── SKILL.md                          Skill instructions and workflow
├── assets/
│   ├── valid_countries.json          747-entry PlanetFWD valid COO list
│   └── aliases.json                  66-entry informal→official alias map
├── scripts/
│   └── validate_coo.py               Main validation script
└── references/
    └── methodology.md                This document
```

---

*Document created as part of the `country_validation` skill development. For questions, contact the PlanetFWD data team.*
