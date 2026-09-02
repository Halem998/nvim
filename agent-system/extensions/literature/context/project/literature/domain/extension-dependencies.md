# Literature Extension Dependencies

## Declared Dependencies

`manifest.json`'s `dependencies` array declares only `core`. Nothing else is auto-loaded when
the literature extension is loaded.

## `filetypes` Is NOT a Transitive Dependency

`filetypes` is deliberately absent from the dependency array. The literature PDF/DJVU-to-markdown
pipeline (`literature-convert.sh` -> `literature-chunk.sh` -> `literature-build-index.sh`) never
calls into `filetypes`'s docx/xlsx/pptx-editing tooling — the two extensions share no code path.

A repo whose workflow relies on `filetypes` capabilities being present alongside `literature`
(for example via a shared cascade through `lean` or `cslib`) must load `filetypes` explicitly
rather than expecting it bundled in with `literature`.

## Why This Matters

Adding `filetypes` to the dependency array would silently pull an unrelated document-editing
toolchain into every repo that loads literature, inflating the deployed surface for no functional
gain. The explicit-load requirement keeps the dependency edge where the actual need is.

## Optional External Binaries (Gracefully Detected, Never Provisioned)

Beyond the manifest-declared extension dependency above, `literature-convert.sh` also calls out
to a handful of plain external CLI binaries that this repo does not provision, vendor, or
version-pin — each is detected via `command -v` and its absence degrades gracefully (a clear
stderr message and a non-zero return, never a crash and never a silent substitution of a
different engine): `pdftotext` (the explicit, best-effort `pdftotext` mode), `djvutxt` /
`djvups` + `ps2pdf` (DJVU conversion), and `ocrmypdf` + `tesseract` (the explicit
`LITERATURE_CONVERTER=ocr` mode).

This is a deliberately different contract from the PRIMARY tier's dependency,
`pymupdf4llm`: that one is a pinned Python package installed into an auto-provisioned `uv` venv
(see `literature-pyenv-provision.sh`) — this repo controls its exact version and installation.
`ocrmypdf`/`tesseract` and the other binaries above are ordinary system packages an operator
installs (or not) outside this repo's control; the pipeline only ever checks whether they happen
to be on `PATH` at call time. Never assume any of them are present, and never add auto-install
logic for them — that would silently convert an explicit, operator-invoked escape hatch into an
implicit repo dependency, which the `pdftotext`/`ocr` modes exist specifically to avoid becoming
part of `auto`'s automatic chain.
