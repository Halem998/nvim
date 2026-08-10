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
