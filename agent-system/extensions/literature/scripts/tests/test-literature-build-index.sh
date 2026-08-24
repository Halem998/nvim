#!/usr/bin/env bash
# test-literature-build-index.sh - Regression tests for literature-build-index.sh's
# dot-prefixed-directory exclusion, duplicate-doc_id detection, and database-derived
# per-doc_id stats.
#
# Locks in the fix for the defect where manifest discovery had no prune guard, so a
# rebuild descended into .backups/ and any other dot-prefixed directory and indexed
# superseded chunk manifests as if they were live. See
# ../../context/project/literature/domain/corpus-directory-conventions.md for the
# documented "live corpus directory" predicate this suite exercises.
#
# All test runs write to a scratch mktemp directory ONLY. This suite MUST NOT read
# from or write to ~/Projects/Literature/ (the real corpus).
#
# Usage:
#   .claude/scripts/tests/test-literature-build-index.sh
#
# Exit codes: 0 — all required tests passed; 1 — a required test failed.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
BUILD_INDEX_SH="$SCRIPT_DIR/literature-build-index.sh"

PASS=0
FAIL=0

t_log() { echo "[test-build-index] $*" >&2; }
t_pass() { PASS=$((PASS + 1)); t_log "PASS: $*"; }
t_fail() { FAIL=$((FAIL + 1)); t_log "FAIL: $*"; }

if [ ! -f "$BUILD_INDEX_SH" ]; then
  t_log "literature-build-index.sh not found at $BUILD_INDEX_SH"
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  t_log "sqlite3 not available; cannot run this suite"
  exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

chunk_ids_in_db() {
  # $1 = db path
  sqlite3 "$1" "SELECT chunk_id FROM chunks_data ORDER BY chunk_id;" 2>/dev/null
}

doc_counts_in_db() {
  # $1 = db path
  sqlite3 "$1" "SELECT doc_id, COUNT(*) FROM chunks_data GROUP BY doc_id ORDER BY doc_id;" 2>/dev/null
}

# ============================================================
# Fixture (Tests A, B, C): a live doc/chunks.json for doc_id "fixture_doc" with two
# chunks, plus a superseded .backups/<label>/chunks.json for the SAME doc_id, sharing
# one chunk_id (fixture_c1, the overlap) and adding one chunk_id that exists ONLY in
# the backup (fixture_stale) — the exact "stale survivor" shape that INSERT OR REPLACE
# alone cannot clean up; only excluding the backup manifest from discovery can.
# ============================================================

make_fixture_a() {
  local root="$1"
  mkdir -p "$root/sources/fixture_doc"
  cat > "$root/sources/fixture_doc/chunks.json" <<'EOF'
[
  {"chunk_id":"fixture_c1","doc_id":"fixture_doc","title":"t1","section_path":"s1","source_path":"chunk_0001.md"},
  {"chunk_id":"fixture_c2","doc_id":"fixture_doc","title":"t2","section_path":"s2","source_path":"chunk_0002.md"}
]
EOF
  echo "live chunk 1" > "$root/sources/fixture_doc/chunk_0001.md"
  echo "live chunk 2" > "$root/sources/fixture_doc/chunk_0002.md"

  mkdir -p "$root/.backups/fixture_doc_old"
  cat > "$root/.backups/fixture_doc_old/chunks.json" <<'EOF'
[
  {"chunk_id":"fixture_c1","doc_id":"fixture_doc","title":"t1","section_path":"s1","source_path":"chunk_0001.md"},
  {"chunk_id":"fixture_stale","doc_id":"fixture_doc","title":"t3","section_path":"s3","source_path":"chunk_0003.md"}
]
EOF
  echo "backup chunk 1" > "$root/.backups/fixture_doc_old/chunk_0001.md"
  echo "backup stale chunk" > "$root/.backups/fixture_doc_old/chunk_0003.md"
}

# --- Test A (criterion 1): with backup present vs. removed, identical chunk_id set
# and identical per-doc_id counts ---

WITH_BACKUP="$WORKDIR/testA_with_backup"
make_fixture_a "$WITH_BACKUP"
bash "$BUILD_INDEX_SH" --dir "$WITH_BACKUP" >/dev/null 2>"$WORKDIR/testA_with.log"
WITH_IDS=$(chunk_ids_in_db "$WITH_BACKUP/.literature.db")
WITH_COUNTS=$(doc_counts_in_db "$WITH_BACKUP/.literature.db")

WITHOUT_BACKUP="$WORKDIR/testA_without_backup"
make_fixture_a "$WITHOUT_BACKUP"
rm -rf "$WITHOUT_BACKUP/.backups"
bash "$BUILD_INDEX_SH" --dir "$WITHOUT_BACKUP" >/dev/null 2>"$WORKDIR/testA_without.log"
WITHOUT_IDS=$(chunk_ids_in_db "$WITHOUT_BACKUP/.literature.db")
WITHOUT_COUNTS=$(doc_counts_in_db "$WITHOUT_BACKUP/.literature.db")

if [ "$WITH_IDS" = "$WITHOUT_IDS" ] && [ "$WITH_COUNTS" = "$WITHOUT_COUNTS" ]; then
  t_pass "Test A (criterion 1): chunk_id set and per-doc_id counts identical with/without intact .backups/ manifest"
else
  t_fail "Test A (criterion 1): chunk_id set or per-doc_id counts DIFFER between with-backup and without-backup runs"
  t_log "  with-backup ids: $WITH_IDS"
  t_log "  without-backup ids: $WITHOUT_IDS"
fi

# --- Test B: the backup-only chunk_id ("fixture_stale") is absent from the built
# database even when the backup manifest is present on disk ---

if ! echo "$WITH_IDS" | grep -qx "fixture_stale"; then
  t_pass "Test B: stale-only chunk_id 'fixture_stale' (present only in the backup manifest) is absent from the built database"
else
  t_fail "Test B: stale-only chunk_id 'fixture_stale' leaked into the built database"
fi

# ============================================================
# Test C: a dot-prefixed directory NESTED below the top level (the .chunks/ shape
# found in the live corpus) is also excluded, not just a root-level dot directory.
# ============================================================

NESTED="$WORKDIR/testC_nested"
mkdir -p "$NESTED/sources/nested_doc"
cat > "$NESTED/sources/nested_doc/chunks.json" <<'EOF'
[{"chunk_id":"nested_live","doc_id":"nested_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"}]
EOF
echo "live" > "$NESTED/sources/nested_doc/chunk_0001.md"
mkdir -p "$NESTED/sources/nested_doc/.chunks/oldpart"
cat > "$NESTED/sources/nested_doc/.chunks/oldpart/chunks.json" <<'EOF'
[{"chunk_id":"nested_stale","doc_id":"nested_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"}]
EOF
echo "stale" > "$NESTED/sources/nested_doc/.chunks/oldpart/chunk_0001.md"

bash "$BUILD_INDEX_SH" --dir "$NESTED" >/dev/null 2>"$WORKDIR/testC.log"
NESTED_IDS=$(chunk_ids_in_db "$NESTED/.literature.db")

if echo "$NESTED_IDS" | grep -qx "nested_live" && ! echo "$NESTED_IDS" | grep -qx "nested_stale"; then
  t_pass "Test C: nested dot-prefixed directory (.chunks/ shape, 3 levels down) is excluded"
else
  t_fail "Test C: nested dot-prefixed directory exclusion failed — ids: $NESTED_IDS"
fi

# ============================================================
# Test D: --dir pointed DIRECTLY at a dot-named directory still indexes it (the
# -mindepth 1 guard: the prune only tests directories found BELOW the target, never
# the target itself).
# ============================================================

DOTTARGET_ROOT="$WORKDIR/testD_root"
mkdir -p "$DOTTARGET_ROOT/.backups/dotdoc"
cat > "$DOTTARGET_ROOT/.backups/dotdoc/chunks.json" <<'EOF'
[{"chunk_id":"dot_target_chunk","doc_id":"dot_target_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"}]
EOF
echo "content" > "$DOTTARGET_ROOT/.backups/dotdoc/chunk_0001.md"

bash "$BUILD_INDEX_SH" --dir "$DOTTARGET_ROOT/.backups" >/dev/null 2>"$WORKDIR/testD.log"
DOTTARGET_IDS=$(chunk_ids_in_db "$DOTTARGET_ROOT/.backups/.literature.db")

if echo "$DOTTARGET_IDS" | grep -qx "dot_target_chunk"; then
  t_pass "Test D: --dir pointed directly at a dot-named directory still indexes it (-mindepth 1 guard)"
else
  t_fail "Test D: explicit dot-named --dir target was NOT indexed — ids: $DOTTARGET_IDS"
fi

# ============================================================
# Test E (criterion 2): two live manifests sharing a doc_id — default run warns with
# both paths named and exits 0; --strict-duplicates reports both and exits 3.
# ============================================================

DUP_ROOT="$WORKDIR/testE_dup"
mkdir -p "$DUP_ROOT/manifestA" "$DUP_ROOT/manifestB"
cat > "$DUP_ROOT/manifestA/chunks.json" <<'EOF'
[{"chunk_id":"dupA1","doc_id":"dup_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"}]
EOF
echo "a" > "$DUP_ROOT/manifestA/chunk_0001.md"
cat > "$DUP_ROOT/manifestB/chunks.json" <<'EOF'
[{"chunk_id":"dupB1","doc_id":"dup_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"}]
EOF
echo "b" > "$DUP_ROOT/manifestB/chunk_0001.md"

STDERR_E_DEFAULT="$WORKDIR/testE_default.log"
bash "$BUILD_INDEX_SH" --dir "$DUP_ROOT" >/dev/null 2>"$STDERR_E_DEFAULT"
EXIT_E_DEFAULT=$?

if [ "$EXIT_E_DEFAULT" -eq 0 ] \
   && grep -q "duplicate doc_id 'dup_doc'" "$STDERR_E_DEFAULT" \
   && grep -q "$DUP_ROOT/manifestA/chunks.json" "$STDERR_E_DEFAULT" \
   && grep -q "$DUP_ROOT/manifestB/chunks.json" "$STDERR_E_DEFAULT"; then
  t_pass "Test E (default): duplicate doc_id warns with both paths named, exits 0"
else
  t_fail "Test E (default): expected exit 0 with both manifest paths named — got exit $EXIT_E_DEFAULT, stderr:"
  cat "$STDERR_E_DEFAULT" >&2
fi

rm -f "$DUP_ROOT/.literature.db" "$DUP_ROOT/.literature.db.tmp"
STDERR_E_STRICT="$WORKDIR/testE_strict.log"
bash "$BUILD_INDEX_SH" --dir "$DUP_ROOT" --strict-duplicates >/dev/null 2>"$STDERR_E_STRICT"
EXIT_E_STRICT=$?

if [ "$EXIT_E_STRICT" -eq 3 ] \
   && grep -q "$DUP_ROOT/manifestA/chunks.json" "$STDERR_E_STRICT" \
   && grep -q "$DUP_ROOT/manifestB/chunks.json" "$STDERR_E_STRICT"; then
  t_pass "Test E (--strict-duplicates): reports both paths and exits 3"
else
  t_fail "Test E (--strict-duplicates): expected exit 3 with both manifest paths named — got exit $EXIT_E_STRICT, stderr:"
  cat "$STDERR_E_STRICT" >&2
fi

if [ -f "$DUP_ROOT/.literature.db.tmp" ]; then
  t_fail "Test E (--strict-duplicates): stray .literature.db.tmp left behind after fatal exit"
else
  t_pass "Test E (--strict-duplicates): no stray .literature.db.tmp left behind"
fi

# ============================================================
# Test F (scope direction 4): a mismatch between a doc_id's declared chunk count
# (summed across its claiming manifests) and its actual database row count produces
# a per-doc_id warning line naming both numbers.
# ============================================================

MISMATCH_ROOT="$WORKDIR/testF_mismatch"
mkdir -p "$MISMATCH_ROOT/live" "$MISMATCH_ROOT/dup"
cat > "$MISMATCH_ROOT/live/chunks.json" <<'EOF'
[
  {"chunk_id":"mm_shared","doc_id":"mismatch_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"},
  {"chunk_id":"mm_2","doc_id":"mismatch_doc","title":"t","section_path":"s","source_path":"chunk_0002.md"}
]
EOF
echo "1" > "$MISMATCH_ROOT/live/chunk_0001.md"
echo "2" > "$MISMATCH_ROOT/live/chunk_0002.md"
cat > "$MISMATCH_ROOT/dup/chunks.json" <<'EOF'
[
  {"chunk_id":"mm_shared","doc_id":"mismatch_doc","title":"t","section_path":"s","source_path":"chunk_0001.md"},
  {"chunk_id":"mm_3","doc_id":"mismatch_doc","title":"t","section_path":"s","source_path":"chunk_0003.md"}
]
EOF
echo "1" > "$MISMATCH_ROOT/dup/chunk_0001.md"
echo "3" > "$MISMATCH_ROOT/dup/chunk_0003.md"

STDERR_F="$WORKDIR/testF.log"
bash "$BUILD_INDEX_SH" --dir "$MISMATCH_ROOT" >/dev/null 2>"$STDERR_F"

if grep -q "chunk-count mismatch: declared=4, actual=3" "$STDERR_F"; then
  t_pass "Test F (scope direction 4): declared/actual chunk-count mismatch warning names both numbers"
else
  t_fail "Test F (scope direction 4): expected mismatch warning naming declared=4, actual=3 — stderr:"
  cat "$STDERR_F" >&2
fi

# ============================================================
# Clean-run sanity: a run with no duplicates and no cross-manifest mismatch prints no
# mismatch lines and no duplicate warnings.
# ============================================================

CLEAN_ROOT="$WORKDIR/clean"
mkdir -p "$CLEAN_ROOT/docX"
cat > "$CLEAN_ROOT/docX/chunks.json" <<'EOF'
[{"chunk_id":"cx1","doc_id":"docX","title":"t","section_path":"s","source_path":"chunk_0001.md"}]
EOF
echo "content" > "$CLEAN_ROOT/docX/chunk_0001.md"
STDERR_CLEAN="$WORKDIR/clean.log"
bash "$BUILD_INDEX_SH" --dir "$CLEAN_ROOT" >/dev/null 2>"$STDERR_CLEAN"
if ! grep -qE "WARNING: duplicate doc_id|chunk-count mismatch" "$STDERR_CLEAN"; then
  t_pass "Clean run: no duplicate or mismatch warnings"
else
  t_fail "Clean run: unexpected warning present — stderr:"
  cat "$STDERR_CLEAN" >&2
fi

# ============================================================
# Corpus-mutation guard: confirm this suite never touched the real corpus.
# ============================================================

REAL_LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
if [ -d "$REAL_LIT_DIR" ]; then
  t_log "Corpus-mutation guard: this suite operates exclusively under $WORKDIR (mktemp); $REAL_LIT_DIR was never referenced by any test above."
fi

# ============================================================
# Summary
# ============================================================

t_log "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
