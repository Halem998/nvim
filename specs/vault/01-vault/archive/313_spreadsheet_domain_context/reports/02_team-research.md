# Research Report: Task #313

**Task**: spreadsheet_domain_context
**Date**: 2026-03-27
**Mode**: Team Research (2 teammates)
**Focus**: Best practices for spreadsheet generation with Claude Code and Typst integration

## Summary

Research confirms that Claude Code has robust spreadsheet generation capabilities in 2026, with three primary approaches: Anthropic's official `xlsx` skill (Python + openpyxl), MCP server integrations (Excel/Google Sheets), and direct Python script generation. For importing spreadsheet values into Typst documents, Typst has native built-in functions (`csv()`, `json()`, `yaml()`) that enable adaptive/data-driven numbers without external packages. The recommended workflow is: generate spreadsheet -> export to JSON/CSV -> Typst reads at compile time -> values appear inline.

## Key Findings

### Spreadsheet Generation (from Teammate A)

1. **Anthropic provides an official `xlsx` skill** using pandas + openpyxl with:
   - LibreOffice-based formula recalculation via `scripts/recalc.py`
   - Zero tolerance for formula errors (`#REF!`, `#DIV/0!`, etc.)
   - Financial modeling color conventions (blue=inputs, black=formulas)

2. **MCP Server ecosystem is mature** with multiple options:
   - Excel: negokaz, haris-musa, sbroenne (up to 230 operations, VBA support)
   - Google Sheets: Composio (40+ tools), ringo380, xing5

3. **Formula-native generation is critical** for financial models:
   - Write `=SUM(B2:B9)` not hardcoded computed values
   - openpyxl writes formula strings; LibreOffice verifies them

4. **Library recommendations**:
   - openpyxl: Read/write existing xlsx with formulas
   - xlsxwriter: Create new xlsx with rich charts
   - pandas: Data manipulation layer
   - xlwings: Live Excel automation (Windows)

### Typst Integration (from Teammate B)

1. **Native data loading functions** (no packages required):
   - `csv(path, row-type: dictionary)` - returns 2D array/dicts
   - `json(path)` - preserves types (numbers stay numbers)
   - `yaml(path)` / `toml(path)` - for configuration values

2. **Inline text interpolation** with `#variable` syntax:
   ```typst
   #let metrics = json("data.json")
   Revenue reached $#metrics.q3.revenue million.
   ```

3. **Direct Excel import packages** on Typst Universe:
   - `spreet` (0.1.0) - Native xlsx/ods decoding
   - `rexllent` / `exmllent` - Excel-to-table with styling
   - `tabut` (1.0.2) - Ergonomic CSV-to-table with filtering

4. **Recommended intermediate format**: JSON over CSV because:
   - Preserves number types automatically
   - Supports hierarchical structure
   - One file can hold all document variables

## Synthesis

### Recommended End-to-End Workflow

```
1. GENERATE: Claude Code xlsx skill creates financial model
   -> Output: report.xlsx with native Excel formulas

2. EXPORT: Python script extracts key metrics to JSON
   -> Output: metrics.json with typed values

3. IMPORT: Typst document loads JSON at compile time
   -> #let m = json("metrics.json")
   -> Inline: "Revenue: $#m.revenue million"

4. AUTOMATE: Watch script triggers recompilation
   -> Spreadsheet changes flow to PDF automatically
```

### Approach Selection Matrix

| Use Case | Spreadsheet Tool | Export Format | Typst Method |
|----------|-----------------|---------------|--------------|
| Financial model with formulas | xlsx skill + openpyxl | JSON (metrics only) | `json()` inline |
| Simple data tables | Direct CSV generation | CSV | `tabut` package |
| Existing Excel file | MCP server or spreet | Direct import | `spreet` package |
| Configuration values | Manual YAML | YAML | `yaml()` inline |

### Conflicts Resolved

**None** - The two research angles were complementary rather than conflicting. Teammate A focused on generation, Teammate B on import, with clear integration points.

### Gaps Identified

1. **Automation tooling**: No specific MCP server for Typst compilation pipeline
2. **Formula extraction**: No direct way to export Excel formula results to JSON (requires LibreOffice recalc step)
3. **Live sync**: Typst requires recompilation; no hot-reload from spreadsheets

### Recommendations

1. **For this project (founder extension spreadsheets)**:
   - Generate XLSX with native formulas using openpyxl
   - Export summary metrics to JSON via Python script
   - Typst templates use `json()` for adaptive values

2. **For general spreadsheet agent design**:
   - Support both XLSX output and CSV/JSON export
   - Include formula validation via LibreOffice
   - Provide JSON export command for Typst integration

3. **For Typst templates**:
   - Use JSON for numeric metrics (type preservation)
   - Use CSV + `tabut` for data tables
   - Consider `spreet` if direct xlsx import needed

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Spreadsheet Generation Best Practices | completed | high |
| B | Typst Spreadsheet Value Import | completed | high |

## References

### Spreadsheet Generation
- [Anthropic xlsx skill](https://claude-plugins.dev/skills/@anthropics/skills/xlsx)
- [Excel MCP servers on GitHub](https://github.com/negokaz/excel-mcp-server)
- [Google Sheets MCP - Composio](https://composio.dev/toolkits/googlesheets/framework/claude-code)
- [openpyxl vs xlsxwriter comparison](https://hive.blog/python/@geekgirl/openpyxl-vs-xlsxwriter-the-ultimate-showdown-for-excel-automation)

### Typst Integration
- [Typst CSV function](https://typst.app/docs/reference/data-loading/csv)
- [Typst JSON function](https://typst.app/docs/reference/data-loading/json/)
- [spreet package](https://typst.app/universe/package/spreet/)
- [tabut package](https://typst.app/universe/package/tabut/)

See individual teammate reports for complete source lists:
- `02_teammate-a-findings.md` - 23 sources on spreadsheet generation
- `02_teammate-b-findings.md` - 13 sources on Typst data loading
