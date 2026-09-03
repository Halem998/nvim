Second-consumer regression spot-check for literature-discover.sh's Tier 1 keyword search (Phase 5
task 2). Query: "ehrenfeucht fraisse games composition finite model theory", same live
~/Projects/Literature/index.json in both runs.

before/ uses the pristine (pre-Phase-2) literature-term-match.sh.
after/  uses the edited (fork-free pure-bash) literature-term-match.sh, matching the deployed
        source-store version.

Result: tier1-results.json is byte-identical between before/ and after/ (4 doc_ids: hodkinson_2006,
blackburn_2002_book, libkin_2004_ch3_ch7, thomas_1997). Tier 2 (Zotero) and Tier 3 (Semantic
Scholar, which returned a live 429 rate-limit in both runs) are unaffected by this task's edits and
are not part of the claim -- only the Tier 1 comparison exercises the shared-helper change.
