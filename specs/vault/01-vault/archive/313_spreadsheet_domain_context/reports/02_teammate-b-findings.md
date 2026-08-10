# Teammate B Findings: Typst Spreadsheet Value Import

## Key Findings

- Typst has **native built-in data loading functions** for CSV, JSON, YAML, TOML, XML, and CBOR - no packages required for basic data import
- The `csv()` function returns a 2D array of strings; with `row-type: dictionary` each row becomes a dict keyed by header names
- The `json()` function preserves types (numbers stay as numbers, booleans as booleans) making it superior to CSV for typed data
- Data loaded via `let` bindings can be used **inline in text paragraphs** with `#variable` syntax, not just in tables
- The Typst Universe ecosystem has **dedicated packages** for direct Excel/ODS import: `spreet`, `rexllent`, and `exmllent`
- The `tabut` package provides the most ergonomic CSV-to-table workflow with filtering, sorting, and column selection
- A practical workflow is: spreadsheet -> export to CSV/JSON -> Typst reads file at compile time -> values appear in document
- Typst does **not** have live/hot-reload from spreadsheets; recompilation is required when data changes, but this can be automated
- YAML and TOML are excellent formats for named configuration variables (e.g., key metrics) that appear inline in document text

## Recommended Approaches

### Approach 1: JSON as intermediate format (RECOMMENDED for typed data)
**Pros**: Preserves number types automatically; hierarchical structure maps naturally to document sections; readable format; one JSON file can hold all document variables
**Cons**: Manual export step from spreadsheet required; not all spreadsheet users know JSON
**Pattern**: Export spreadsheet metrics to `data.json` -> `#let data = json("data.json")` -> use `#data.revenue` inline

### Approach 2: CSV with `row-type: dictionary` (RECOMMENDED for tabular data)
**Pros**: Native Typst support; easy to export from any spreadsheet; tabut package makes it ergonomic
**Cons**: All values are strings (must parse numbers manually); no nested structure
**Pattern**: Export sheet as `data.csv` -> `#let rows = csv("data.csv", row-type: dictionary)` -> access `#rows.at(0).revenue`

### Approach 3: YAML for named document variables
**Pros**: Human-readable key-value pairs; ideal for single named values scattered throughout text; copy-paste from spreadsheet is straightforward
**Cons**: Manual maintenance; no direct spreadsheet export format
**Pattern**: Maintain `vars.yaml` with named values -> `#let v = yaml("vars.yaml")` -> `The revenue was #v.q3_revenue.`

### Approach 4: Direct Excel/ODS import via `spreet` package
**Pros**: No intermediate file; reads `.xlsx` and `.ods` natively; preserves worksheet structure
**Cons**: Still returns strings (no type conversion); version 0.1.0 (early-stage); 335 kB package weight
**Pattern**: `#import "@preview/spreet:0.1.0"` -> `#let data = spreet.file-decode("report.xlsx")`

### Approach 5: Excel-to-table via `rexllent` package
**Pros**: Full table rendering with styling (borders, fill colors, alignment); WASM-powered; preserves visual formatting
**Cons**: Optimized for full table display, not individual value extraction; less suitable for inline scalar values
**Pattern**: `#xlsx-parser(read("report.xlsx", encoding: none))`

## Evidence/Examples

### Native CSV with dictionary rows (inline value access)
```typst
#let data = csv("metrics.csv", row-type: dictionary)
#let q3 = data.at(0)

The Q3 revenue was $#q3.revenue million, with #q3.growth% growth.
```

### Native JSON for typed values
```typst
#let metrics = json("quarterly.json")

Revenue reached $#metrics.q3.revenue million in Q3,
up from $#metrics.q2.revenue million the prior quarter.
```

### YAML for sparse named variables
```typst
#let v = yaml("report-vars.yaml")

The study enrolled #v.participant_count participants
across #v.site_count sites over #v.duration_months months.
```

### Tabut package for ergonomic CSV tables
```typst
#import "@preview/tabut:1.0.2": records-from-csv, tabut

#let data = records-from-csv(csv("sales.csv"))

#tabut(data, (
  (header: [Quarter], func: r => r.quarter),
  (header: [Revenue], func: r => r.revenue),
  (header: [Growth], func: r => r.growth),
))
```

### Direct Excel import with spreet
```typst
#import "@preview/spreet:0.1.0"

#let book = spreet.file-decode("report.xlsx")
#let sheet = book.at("Sheet1")
// sheet is array of arrays of strings
#let q3_row = sheet.at(3)  // row index
```

### Automation workflow (shell script)
```bash
# Export from LibreOffice Calc to JSON
libreoffice --headless --convert-to json report.ods
# Or use Python/pandas to export specific cells
python3 export_metrics.py > data/metrics.json
# Compile Typst document
typst compile report.typ
```

### Key Typst built-in functions confirmed
- `csv(path, delimiter: ",", row-type: array|dictionary)` -> array
- `json(path)` -> any (type-preserving)
- `yaml(path)` -> any
- `toml(path)` -> dictionary
- `xml(path)` -> dictionary
- `cbor(path)` -> any

## Confidence Level

**High** - The research is based on official Typst documentation with direct function API details. The native `csv()`, `json()`, and `yaml()` functions are well-documented core language features, not experimental. The package ecosystem (spreet, tabut, rexllent) is live on Typst Universe with real version numbers and MIT licenses. The inline text interpolation pattern (`#variable`) is a fundamental Typst feature confirmed by multiple sources.

The only uncertainty is around workflow automation (how users trigger recompilation when data changes), which is an environment-specific concern outside Typst itself.

## Sources

- [CSV Function - Typst Documentation](https://typst.app/docs/reference/data-loading/csv)
- [JSON Function - Typst Documentation](https://typst.app/docs/reference/data-loading/json/)
- [Data Loading - Typst Documentation](https://typst.app/docs/reference/data-loading/)
- [YAML Function - Typst Documentation](https://typst.app/docs/reference/data-loading/yaml/)
- [TOML Function - Typst Documentation](https://typst.app/docs/reference/data-loading/toml/)
- [tabut - Typst Universe](https://typst.app/universe/package/tabut/)
- [spreet - Typst Universe](https://typst.app/universe/package/spreet/)
- [rexllent - Typst Universe](https://typst.app/universe/package/rexllent/)
- [exmllent - Typst Universe](https://typst.app/universe/package/exmllent/)
- [tblr - Typst Universe](https://typst.app/universe/package/tblr/)
- [Displaying specific data from CSV file - Typst Forum](https://forum.typst.app/t/displaying-specific-data-from-csv-file/1283)
- [Cast data in CSV files to Typst types - GitHub Issue #6785](https://github.com/typst/typst/issues/6785)
- [Scripting - Typst Documentation](https://typst.app/docs/reference/scripting/)
