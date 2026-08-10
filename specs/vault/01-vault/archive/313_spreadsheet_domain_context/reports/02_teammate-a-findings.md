# Teammate A Findings: Spreadsheet Generation Best Practices

## Key Findings

- **Three primary integration paths exist for Claude Code**: (1) direct Python script generation using openpyxl/xlsxwriter, (2) MCP servers for live Excel/Google Sheets interaction, and (3) Claude Code Skills (markdown-defined workflows)
- **Anthropic provides an official `xlsx` skill** that uses pandas + openpyxl, enforces zero formula errors, and uses LibreOffice for formula recalculation/verification via `scripts/recalc.py`
- **Multiple mature MCP servers exist** for both Excel (negokaz, haris-musa, sbroenne, guillehr2) and Google Sheets (Composio, ringo380, xing5)
- **openpyxl is the recommended library** for complex Excel generation with formulas, formatting, and financial modeling; xlsxwriter is preferred for output-heavy tasks with charts
- **XLSX format dominates** for financial modeling and human-facing output; CSV is preferred only for machine-to-machine pipelines
- **Formula-native generation is a hard requirement** for financial models: Claude Code skills mandate writing `=SUM(B2:B9)` rather than computing values in Python and hardcoding them
- **LibreOffice-based recalculation** is the standard mechanism for verifying formula correctness in generated files (since openpyxl writes formula strings but not calculated values)
- **Financial modeling conventions** are baked into the Anthropic xlsx skill: color-coded cells (blue for inputs, black for formulas, green for internal links, red for external links)
- **Microsoft Copilot in Excel (2026)** now supports Claude Opus 4.5 as an alternative reasoning model alongside GPT 5.2, representing convergence between AI coding and spreadsheet-native AI

## Recommended Approaches

### 1. Anthropic's Official `xlsx` Skill (Best for Claude Code-native workflows)
**Approach**: Load the Anthropic xlsx skill into Claude Code; Claude writes Python scripts using pandas + openpyxl that are then executed.

**Pros**:
- Official support, actively maintained by Anthropic
- Zero-error guarantee with formula validation
- LibreOffice recalculation built in
- Financial modeling conventions pre-encoded
- Handles multi-sheet workbooks, charts, conditional formatting

**Cons**:
- Requires LibreOffice installed on the system
- Python execution required (code execution tool must be enabled)
- Not interactive/live -- generates files rather than editing live spreadsheets

**Best for**: Automated report generation, financial models, CI/CD pipelines generating Excel deliverables

---

### 2. Excel MCP Servers (Best for live editing existing files)
**Top options**: `negokaz/excel-mcp-server` (Go-based, xlsx/xlsm support), `haris-musa/excel-mcp-server` (Python/openpyxl, charts, pivot tables), `sbroenne/mcp-server-excel` (25 tools, 230 operations including VBA, Power Query, PivotTables)

**Pros**:
- Live read/write to existing Excel files
- No need to regenerate entire file
- Windows versions can edit open Excel files
- Natural language commands map to spreadsheet operations

**Cons**:
- Adds MCP server dependency (Node.js or Python server running)
- Not all servers support formula-based generation (some overwrite with values)
- Varying feature completeness across servers

**Best for**: Iterative editing of existing workbooks, enterprise workflows with pre-existing templates

---

### 3. Google Sheets MCP (Best for collaborative/cloud workflows)
**Top options**: Composio Google Sheets toolkit (40+ tools), `ringo380/claude-google-sheets-mcp`, `xing5/mcp-google-sheets`

**Pros**:
- Real-time collaboration in the cloud
- No file management overhead
- Rich API (bulk updates, SQL queries, chart generation)
- Accessible from anywhere without file sharing

**Cons**:
- Requires Google Workspace authentication (OAuth)
- Internet dependency
- More complex setup (API keys, MCP URL generation)
- Formula support less robust than native XLSX

**Best for**: Team collaboration, dashboards, data pipelines feeding into business reporting

---

### 4. Direct Python Script Generation (Best for reproducibility and CI/CD)
**Libraries**: openpyxl (read/write, formulas, formatting), xlsxwriter (write-only, superior charts), pandas (data manipulation layer), xlwings (live Excel automation)

**Pros**:
- Full programmatic control
- Reproducible, version-controllable scripts
- No external dependencies beyond Python libraries
- Can embed native Excel formulas

**Cons**:
- Claude Code must generate and execute Python scripts
- No live editing of open files (except xlwings)
- Requires validation step (LibreOffice or manual review)

**Best for**: Template-driven report generation, financial model automation, ETL pipelines

## Evidence/Examples

### Anthropic's xlsx Skill Pattern
From the official skill documentation at `claude-plugins.dev/skills/@anthropics/skills/xlsx`:
- Uses `pandas` for data analysis and `openpyxl` for Excel-specific features
- Color convention: blue = inputs, black = formulas, green = internal links, red = external links
- Formula requirement: `sheet['B10'] = '=SUM(B2:B9)'` (not `sheet['B10'] = 45`)
- Recalculation: `scripts/recalc.py` runs LibreOffice headless to verify all formulas
- Zero tolerance for `#REF!`, `#DIV/0!`, `#VALUE!`, `#N/A`, `#NAME?` errors

### MCP Server Ecosystem (GitHub, 2025-2026)
- `negokaz/excel-mcp-server`: Go-based, reads xlsx/xlsm/xltx/xltm, NPX install, up to 4,000 cells/read
- `haris-musa/excel-mcp-server`: Python/openpyxl, charts, pivot tables, conditional formatting, streamable HTTP transport
- `sbroenne/mcp-server-excel`: 25 tools / 230 operations, COM API (Windows), VBA, Power Query, DAX
- `guillehr2/Excel-MCP-Server-Master`: No Excel installation required, xlsx/xlsm support
- `ivan-loh/mcp-excel`: SQL query interface over Excel/CSV files

### Google Sheets Integration
- Composio toolkit: 40+ tools via `claude mcp add` with HTTP transport; handles create, read, bulk update, chart generation, SQL queries
- `xing5/mcp-google-sheets`: Integrates with Google Drive for creating/modifying spreadsheets

### Financial Modeling Best Practices (Industry Standards 2026)
From Wall Street Prep and FE Training:
- Color-code inputs vs. formulas vs. references (never mix)
- Use `MIN()`/`MAX()` over nested `IF` statements for auditability
- "Repeat and Link" pattern: show assumption, then reference it in formula
- Absolute vs. mixed references critical (`F4` key pattern)
- Every output must be traceable -- dynamic formulas over hardcoded values

### Library Selection Matrix
| Use Case | Recommended Library |
|----------|-------------------|
| Read + modify existing xlsx | openpyxl |
| Create new xlsx with rich charts | xlsxwriter |
| Data manipulation before export | pandas |
| Live Excel automation (Windows) | xlwings |
| Professional add-ins | pyxll (commercial) |

### AI Tool Comparison (2026)
- **Microsoft Copilot in Excel**: Agent Mode writes formulas, creates tables, generates charts; now supports Claude Opus 4.5 as reasoning model
- **GPT for Excel**: Bulk LLM processing inside spreadsheet (bulk translate, categorize, extract)
- **Claude Code with xlsx skill**: Programmatic generation via Python scripts with formula validation
- **Claude for Sheets add-on**: Google Workspace add-on for Sheets (distinct from Claude Code)

## Confidence Level

**High** for:
- Library recommendations (openpyxl vs xlsxwriter vs pandas) -- well-documented, stable ecosystem
- Anthropic xlsx skill capabilities -- directly from official skill documentation
- MCP server landscape -- multiple active GitHub repositories confirmed
- Financial modeling conventions -- industry-standard sources (Wall Street Prep, FE Training)

**Medium** for:
- MCP server quality/reliability -- many are community projects with varying maintenance
- Google Sheets MCP stability -- authentication complexity and API rate limits are real concerns
- LibreOffice as verification mechanism -- works but adds system dependency

**Low** for:
- Long-term MCP server ecosystem stability -- new servers emerge and die frequently
- Specific performance benchmarks across approaches

## Sources

- [Google Sheets MCP Integration with Claude Code | Composio](https://composio.dev/toolkits/googlesheets/framework/claude-code)
- [Excel Automation MCP | Claude Code Spreadsheet Skill](https://mcpmarket.com/tools/skills/excel-automation-mcp)
- [Excel & Financial Modeling | Claude Code Skill](https://mcpmarket.com/tools/skills/excel-financial-modeling-1)
- [xlsx - Claude Skills (Anthropic Official)](https://claude-plugins.dev/skills/@anthropics/skills/xlsx)
- [GitHub - tfriedel/claude-office-skills](https://github.com/tfriedel/claude-office-skills)
- [GitHub - negokaz/excel-mcp-server](https://github.com/negokaz/excel-mcp-server)
- [GitHub - haris-musa/excel-mcp-server](https://github.com/haris-musa/excel-mcp-server)
- [GitHub - sbroenne/mcp-server-excel](https://github.com/sbroenne/mcp-server-excel)
- [GitHub - guillehr2/Excel-MCP-Server-Master](https://github.com/guillehr2/Excel-MCP-Server-Master)
- [GitHub - ivan-loh/mcp-excel](https://github.com/ivan-loh/mcp-excel)
- [GitHub - xing5/mcp-google-sheets](https://github.com/xing5/mcp-google-sheets)
- [GitHub - ringo380/claude-google-sheets-mcp](https://github.com/ringo380/claude-google-sheets-mcp)
- [CSV vs XLSX vs ODS in 2026: Best Spreadsheet Format for Developers](https://blog.fileformat.com/en/spreadsheet/csv-vs-xlsx-vs-ods-in-2026-best-spreadsheet-format-for-developers/)
- [The Best Python Libraries for Excel in 2025](https://sheetflash.com/blog/the-best-python-libraries-for-excel-in-2024)
- [Openpyxl vs XlsxWriter: The Ultimate Showdown](https://hive.blog/python/@geekgirl/openpyxl-vs-xlsxwriter-the-ultimate-showdown-for-excel-automation)
- [Financial Modeling Best Practices 2026](https://www.fe.training/free-resources/financial-modeling/financial-modeling-best-practices/)
- [Financial Modeling Guide | Wall Street Prep](https://www.wallstreetprep.com/knowledge/financial-modeling/)
- [Best AI for Excel: Financial Modeling Guide 2026](https://www.v7labs.com/blog/best-ai-for-excel)
- [How to Convert Excel Spreadsheets to Python Models with Claude Code](https://martinalderson.com/posts/how-to-convert-excel-spreadsheets-to-python-models-with-claude-code/)
- [Use Claude for Excel | Claude Help Center](https://support.claude.com/en/articles/12650343-use-claude-for-excel)
- [Claude AI Spreadsheet Analysis Capabilities](https://www.datastudios.org/post/claude-ai-spreadsheet-analysis-capabilities-and-limits-for-csv-excel-google-sheets-and-api-automa)
