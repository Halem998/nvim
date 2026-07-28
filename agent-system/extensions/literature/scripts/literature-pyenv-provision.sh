#!/usr/bin/env bash
# literature-pyenv-provision.sh - Provision a pinned uv venv for pymupdf4llm,
# with the nix-ld + stdenv.cc.cc.lib LD_LIBRARY_PATH shim needed to run pip-wheel
# compiled extensions (PyMuPDF's `_extra` module) outside a nix-built Python.
#
# This script is dual-mode:
#   - SOURCED (`source literature-pyenv-provision.sh`): defines functions only,
#     no side effects. Callers (literature-convert.sh) use the functions below.
#   - EXECUTED (`./literature-pyenv-provision.sh [provision|python|status]`):
#     runs the requested action directly, useful for manual setup/debugging.
#
# Design contract:
#   - The venv is gitignored and auto-provisioned; never assume it is committed.
#   - Provisioning is idempotent: repeated calls are cheap no-ops once the venv
#     and shim are already known-good.
#   - Graceful detection only: if `uv` is unavailable, provisioning fails, or the
#     nix-ld shim cannot be resolved, functions report unavailability cleanly
#     (return non-zero, print nothing to stdout) so callers can fall back to the
#     mandatory PyMuPDF column-clustering tier — never crash the caller.
#
# Public functions (after sourcing):
#   literature_pyenv_dir                  -> prints the venv directory path
#   literature_pyenv_shim_prefix          -> prints "<cclib>/lib:<NIX_LD_LIBRARY_PATH>"
#                                             (may be empty if unresolvable; not an error)
#   literature_pyenv_ensure               -> idempotently provisions the venv;
#                                             returns 0 on a usable venv, 1 otherwise
#   literature_pyenv_python               -> prints the absolute venv python path
#                                             AND verifies `import pymupdf4llm` works
#                                             under the shim; returns 1 + prints
#                                             nothing if unusable

set -uo pipefail

_LPP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_PYENV_DIR="${LITERATURE_PYENV_DIR:-$_LPP_SCRIPT_DIR/literature-pyenv/venv}"
_LPP_CACHE_DIR="$(dirname "$LITERATURE_PYENV_DIR")"
_LPP_CCLIB_CACHE="$_LPP_CACHE_DIR/.cclib_path"
_LPP_PIN_PYMUPDF4LLM="${LITERATURE_PYMUPDF4LLM_VERSION:-1.28.0}"

_lpp_log() { echo "[pyenv] $*" >&2; }

literature_pyenv_dir() {
  echo "$LITERATURE_PYENV_DIR"
}

# Resolve (and cache) the stdenv.cc.cc.lib store path providing libstdc++.so.6.
# Prints the store path's /lib dir on success; prints nothing and returns 1 on failure.
_literature_pyenv_cclib_dir() {
  if [ -f "$_LPP_CCLIB_CACHE" ]; then
    local cached
    cached="$(cat "$_LPP_CCLIB_CACHE" 2>/dev/null)"
    if [ -n "$cached" ] && [ -d "$cached/lib" ]; then
      echo "$cached/lib"
      return 0
    fi
  fi

  if ! command -v nix-build >/dev/null 2>&1; then
    _lpp_log "nix-build not available; cannot resolve stdenv.cc.cc.lib shim"
    return 1
  fi

  local store_path
  store_path=$(nix-build '<nixpkgs>' -A stdenv.cc.cc.lib --no-out-link 2>/dev/null | tail -1)
  if [ -z "$store_path" ] || [ ! -d "$store_path/lib" ]; then
    _lpp_log "nix-build failed to resolve stdenv.cc.cc.lib"
    return 1
  fi

  mkdir -p "$_LPP_CACHE_DIR"
  echo "$store_path" > "$_LPP_CCLIB_CACHE"
  echo "$store_path/lib"
  return 0
}

# Prints the LD_LIBRARY_PATH prefix to apply when invoking the venv python.
# May print an empty string (not an error) if the shim cannot be resolved --
# on some setups the venv python may still work without it.
literature_pyenv_shim_prefix() {
  local cclib
  cclib="$(_literature_pyenv_cclib_dir 2>/dev/null)"
  if [ -n "$cclib" ]; then
    echo "${cclib}:${NIX_LD_LIBRARY_PATH:-}"
  else
    echo "${NIX_LD_LIBRARY_PATH:-}"
  fi
}

# Idempotently create the venv and install the pinned pymupdf4llm. Never crashes
# the caller: reports failure via return code + stderr log only.
literature_pyenv_ensure() {
  if ! command -v uv >/dev/null 2>&1; then
    _lpp_log "uv not available; skipping pymupdf4llm provisioning (fallback tier will be used)"
    return 1
  fi

  if [ ! -x "$LITERATURE_PYENV_DIR/bin/python" ]; then
    _lpp_log "Creating venv at $LITERATURE_PYENV_DIR"
    if ! uv venv "$LITERATURE_PYENV_DIR" >/dev/null 2>&1; then
      _lpp_log "uv venv creation failed"
      return 1
    fi
  fi

  # Quick idempotency check: is pymupdf4llm already importable UNDER THE SHIM
  # before paying for a reinstall? (Checking without the shim would always
  # report "missing" due to the libstdc++.so.6 ImportError, defeating the
  # idempotency this function is supposed to provide.)
  local shim_check
  shim_check="$(literature_pyenv_shim_prefix)"
  if ! LD_LIBRARY_PATH="$shim_check" "$LITERATURE_PYENV_DIR/bin/python" -c "import pymupdf4llm" >/dev/null 2>&1; then
    _lpp_log "Installing pymupdf4llm==${_LPP_PIN_PYMUPDF4LLM} into venv..."
    if ! uv pip install --python "$LITERATURE_PYENV_DIR/bin/python" \
        "pymupdf4llm==${_LPP_PIN_PYMUPDF4LLM}" >/dev/null 2>&1; then
      _lpp_log "uv pip install pymupdf4llm failed"
      return 1
    fi
  fi

  return 0
}

# Prints the venv python's absolute path ONLY if `import pymupdf4llm` succeeds
# under the resolved shim; prints nothing and returns 1 otherwise. Callers
# should treat empty stdout as "primary engine unavailable, use fallback tier."
literature_pyenv_python() {
  if [ ! -x "$LITERATURE_PYENV_DIR/bin/python" ]; then
    return 1
  fi

  local shim
  shim="$(literature_pyenv_shim_prefix)"

  if LD_LIBRARY_PATH="$shim" "$LITERATURE_PYENV_DIR/bin/python" -c "import pymupdf4llm" >/dev/null 2>&1; then
    echo "$LITERATURE_PYENV_DIR/bin/python"
    return 0
  fi

  return 1
}

# --- Direct-execution mode ---
if ! (return 0 2>/dev/null); then
  ACTION="${1:-provision}"
  case "$ACTION" in
    provision)
      literature_pyenv_ensure
      PY="$(literature_pyenv_python)"
      if [ -n "$PY" ]; then
        SHIM="$(literature_pyenv_shim_prefix)"
        VERSION=$(LD_LIBRARY_PATH="$SHIM" "$PY" -c "import pymupdf4llm; print(pymupdf4llm.__version__)" 2>/dev/null)
        _lpp_log "Provisioned OK: $PY (pymupdf4llm $VERSION)"
        exit 0
      else
        _lpp_log "Provisioning did not result in a usable pymupdf4llm environment; fallback tier will be used"
        exit 1
      fi
      ;;
    python)
      literature_pyenv_python
      ;;
    status)
      echo "venv dir:    $LITERATURE_PYENV_DIR"
      echo "venv python: $([ -x "$LITERATURE_PYENV_DIR/bin/python" ] && echo present || echo absent)"
      echo "shim prefix: $(literature_pyenv_shim_prefix)"
      PY="$(literature_pyenv_python)"
      echo "usable:      $([ -n "$PY" ] && echo yes || echo no)"
      ;;
    *)
      echo "Usage: $0 [provision|python|status]" >&2
      exit 1
      ;;
  esac
fi
