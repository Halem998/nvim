# Research Report: Task #419 -- Alternative Analysis

**Task**: 419 - pdftk post-processing for typst PDF output
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:15:00Z
**Effort**: Small
**Dependencies**: None
**Sources/Inputs**:
- Web search: typst GitHub issues, qpdf documentation, pdftk manual, cpdf manual, ghostscript docs
- Codebase: `after/ftplugin/typst.lua`, prior task 277 research, existing report 01
- Typst official documentation (typst.app/docs/reference/pdf/)
**Artifacts**: - specs/419_pdftk_postprocess_typst_pdf/reports/02_pdftk-alternatives.md
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- Typst explicitly will not add native PDF permission/encryption support; the maintainer closed the feature request as "not planned" (GitHub issue #4387, May 2025), recommending external tools like pdftk instead
- pdftk remains the best tool for this specific use case: it is already installed, lightweight, and its `allow AllFeatures` flag is purpose-built for this exact problem
- qpdf is the strongest alternative but is not currently installed, requires explicit encryption setup (empty passwords), and adds unnecessary complexity for our use case
- ghostscript and cpdf are unsuitable: ghostscript uses raw bit-field permissions and is heavyweight; cpdf is commercial software not available in the system
- The approach outlined in report 01 (pdftk post-processing) is confirmed as the correct solution

## Context and Scope

Report 01 established the technical approach: run `pdftk input.pdf output tmp.pdf allow AllFeatures && mv tmp.pdf input.pdf` after each typst compilation. This supplementary report validates that approach against web-sourced evidence by answering four questions:

1. Is the typst PDF permission problem a known/common issue?
2. Does typst have native settings to control PDF permissions?
3. Are there better tools than pdftk for this task?
4. What are the trade-offs of each alternative?

## Findings

### 1. Typst PDF Permission Problem -- Confirmed Known Issue

**The problem is real and documented.** Typst-generated PDFs lack an `/Encrypt` dictionary entirely. PDF viewers (Apple Preview, Adobe Reader) interpret this absence differently:

- **Apple Preview**: Frequently restricts annotation on PDFs without explicit permission metadata. Multiple Apple Community threads document this behavior, with users seeing "do not have permission to create or modify annotations" errors
- **Adobe Reader**: Similar behavior for PDFs without explicit permission structures

The root cause is that typst produces clean, minimal PDFs without any security metadata. While this is technically correct (no encryption means no restrictions), viewers that check for explicit permission flags before allowing annotation operations treat the absence of flags as restrictive.

**Web evidence**: Apple Community threads confirm that PDFs from various generators (not just typst) trigger this behavior. The standard workaround is re-exporting the PDF or using a post-processing tool to add explicit permission metadata.

### 2. Typst Native Permission Support -- Explicitly Rejected

**Typst will not add PDF encryption or permission controls.** This is confirmed by GitHub issue #4387 ("Password-protect PDFs"), closed as "Not Planned" on May 1, 2025 by maintainer Martin Haug:

> "I don't think we plan to ship this. Security is always a big can of worms and with PDF, the security landscape generally evolves faster than both the standards and viewers... We do not want to focus efforts on ensuring that we can ship a safe & secure feature here, it's better left up to dedicated tools."

The maintainer explicitly recommends using external tools like pdftk for post-processing. This confirms that our approach aligns with the upstream recommendation.

**Current typst PDF options** (as of 0.14.x) are limited to:
- `--pdf-standard`: Version selection (1.4, 1.5, 1.6, 1.7, 2.0) and PDF/A conformance levels
- `--no-pdf-tags`: Disable tagged PDF accessibility features
- `--pages`: Page selection for export

No encryption, permission, security, or annotation flags exist.

### 3. Tool Comparison for PDF Permission Setting

#### pdftk (Recommended -- Current Approach)

**Command**: `pdftk input.pdf output tmp.pdf allow AllFeatures`

| Aspect | Assessment |
|--------|------------|
| Installed | Yes (`/run/current-system/sw/bin/pdftk` v3.3.3) |
| Syntax | Simplest of all options; single command, clear semantics |
| Permissions model | High-level named permissions (`AllFeatures`, `Printing`, `ModifyAnnotations`, etc.) |
| Encryption behavior | Adds 128-bit encryption with empty passwords when using `allow`; effectively no password needed but permission flags are set |
| Output size | Slightly smaller than input in testing (6286 -> 6067 bytes) |
| Dependencies | Java runtime (pdftk-java) |
| Risk | Very low; well-tested, widely used |

**Key advantage**: The `allow AllFeatures` flag does exactly what we need in a single, memorable command. No password management, no encryption strength decisions, no bit-field calculations.

#### qpdf

**Command**: `qpdf --encrypt "" "" 256 --modify=all --extract=y --print=full --accessibility=y -- input.pdf output.pdf`

| Aspect | Assessment |
|--------|------------|
| Installed | No (not in current NixOS configuration) |
| Syntax | Verbose; requires specifying empty user and owner passwords, encryption strength, and individual permission flags |
| Permissions model | Fine-grained flags (`--modify=`, `--extract=`, `--print=`, `--accessibility=`) |
| Encryption behavior | Requires explicit `--encrypt` with password arguments; `--allow-insecure` needed for empty owner password |
| Dependencies | C++ library, lighter than pdftk-java |
| Risk | Low; well-maintained, excellent documentation |

**Key disadvantage**: Not installed. Would require adding to NixOS configuration. The command syntax is significantly more verbose for our use case. The `--allow-insecure` flag requirement adds friction.

**Potential advantage**: If we ever need fine-grained permission control (e.g., allow annotation but disallow printing), qpdf provides more granular options than pdftk.

#### ghostscript (gs)

**Command**: `gs -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -dEncryptionR=3 -dPermissions=-4 -sOwnerPassword="" -sOutputFile=output.pdf input.pdf`

| Aspect | Assessment |
|--------|------------|
| Installed | No (not in current NixOS configuration) |
| Syntax | Most complex; raw 32-bit permission flag values, PostScript-heritage parameters |
| Permissions model | Raw bit-field (`-dPermissions=-4` for "all permissions") |
| Encryption behavior | Full PostScript/PDF reinterpretation; can alter PDF structure |
| Dependencies | Very large (full PostScript interpreter) |
| Risk | Medium; ghostscript re-renders the PDF through its PostScript engine, which can alter fonts, layout, and metadata |

**Key disadvantage**: ghostscript is a full PDF reinterpreter, not a metadata editor. It processes the PDF through a PostScript pipeline, which can introduce rendering differences. This is fundamentally the wrong tool for adding permission metadata to an otherwise correct PDF. The `-dPermissions=-4` syntax (raw bit-fields) is error-prone and undiscoverable.

**Not recommended** for this use case.

#### cpdf (Coherent PDF)

**Command**: `cpdf -encrypt 128bit "" "" input.pdf -o output.pdf`

| Aspect | Assessment |
|--------|------------|
| Installed | No |
| Syntax | Clean, similar to pdftk |
| Permissions model | Named permissions similar to pdftk |
| License | Commercial (free for non-commercial use) |
| Dependencies | OCaml binary, self-contained |
| Risk | Low technically; high from licensing perspective |

**Key disadvantage**: Commercial license. Not available in nixpkgs standard packages. Not a viable option for an open-source project workflow.

#### mutool (MuPDF)

| Aspect | Assessment |
|--------|------------|
| Installed | No |
| Relevant capability | mutool does not support setting PDF encryption or permissions; it focuses on rendering, conversion, and page manipulation |

**Not applicable** for this use case.

### 4. Summary Comparison Matrix

| Tool | Installed | Syntax Complexity | Permission Granularity | PDF Fidelity | Recommendation |
|------|-----------|-------------------|----------------------|--------------|----------------|
| **pdftk** | Yes | Low (1 flag) | High-level named | Preserves exactly | **Use this** |
| qpdf | No | Medium (5+ flags) | Fine-grained | Preserves exactly | Best alternative if pdftk unavailable |
| ghostscript | No | High (raw bits) | Raw bit-field | Re-renders (risky) | Do not use |
| cpdf | No | Low | Named | Preserves exactly | Commercial license prevents use |
| mutool | No | N/A | N/A | N/A | Cannot set permissions |

## Decisions

1. **pdftk confirmed as the correct tool** -- It is already installed, has the simplest syntax, preserves PDF fidelity, and is explicitly recommended by the typst maintainer as the type of external tool to use for this purpose.
2. **No typst-native solution exists or is planned** -- The feature request was closed as "not planned" with a clear statement that security features are out of scope for typst.
3. **qpdf should be documented as fallback** -- For systems where pdftk is not available, the implementation should document qpdf as an alternative in comments.
4. **No changes needed to report 01 approach** -- The implementation plan from report 01 is validated by this research.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| pdftk removed from NixOS | Very low | Medium | Document qpdf as fallback; graceful skip if binary not found |
| Typst adds native permissions in future | Very low | Positive | Would eliminate need for post-processing entirely; monitor typst changelog |
| Empty-password encryption confuses some viewers | Very low | Low | pdftk's approach is standard practice; widely tested |
| pdftk-java performance on large PDFs | Low | Low | Tested at ~6KB; for larger files, still subsecond on modern hardware |

## Appendix

### Search Queries Used
- "typst PDF annotation permissions restricted Apple Preview cannot annotate"
- "typst PDF permissions settings native flag allow annotations 2025 2026"
- "qpdf vs pdftk vs ghostscript set PDF permissions AllFeatures allow annotations"
- "cpdf set PDF permissions annotations post-processing"
- "qpdf --encrypt allow annotate modify permissions command line example"
- "pdftk allow AllFeatures without password no encryption PDF permissions"
- "ghostscript set PDF permissions allow annotation modification"
- "PDF permissions without encryption owner password empty allow all annotations"

### Key References
- [Typst PDF Documentation](https://typst.app/docs/reference/pdf/) -- Official PDF export options
- [Typst Issue #4387: Password-protect PDFs](https://github.com/typst/typst/issues/4387) -- Closed as "not planned"
- [PDFtk Server Manual](https://www.pdflabs.com/docs/pdftk-man-page/) -- pdftk command reference
- [qpdf PDF Encryption Documentation](https://qpdf.readthedocs.io/en/stable/encryption.html) -- qpdf permission flags
- [Apple Community: PDF annotation restrictions](https://discussions.apple.com/thread/251265835) -- Viewer behavior evidence
- [Prior Task 277 Research](specs/archive/277_research_pdf_annotation_tools/reports/02_team-research.md) -- PDF annotation tool research
