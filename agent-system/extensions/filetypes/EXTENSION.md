## Filetypes Extension

File format conversion and manipulation: documents, spreadsheets, presentations, PDF annotations.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-filetypes | filetypes-router-agent | Format detection and routing |
| skill-filetypes | document-agent | Document format conversion (PDF/DOCX/Markdown) |
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst table conversion |
| skill-presentation | presentation-agent | Presentation extraction and slide generation |
| skill-scrape | scrape-agent | PDF annotation extraction |
| skill-docx-edit | docx-edit-agent | In-place DOCX editing with tracked changes (SuperDoc MCP) |
| skill-sheet | sheet-agent | XLSX creation, editing, and analysis (openpyxl) |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/convert` | `/convert file.pdf` | Convert between document formats; `/convert deck.pptx --format beamer` for slide output |
| `/table` | `/table data.xlsx` | Convert spreadsheets to LaTeX/Typst tables |
| `/scrape` | `/scrape paper.pdf` | Extract PDF annotations to Markdown/JSON |
| `/edit` | `/edit file.docx "instruction"` | Edit Office documents in-place (DOCX, XLSX) |
| `/sheet` | `/sheet file.xlsx "instruction"` | Create, edit, or analyze XLSX spreadsheets |
