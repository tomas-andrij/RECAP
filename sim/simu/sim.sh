#!/usr/bin/env bash
set -euo pipefail

log() { printf "[sim] %s\n" "$*"; }
die() { printf "[sim][ERR] %s\n" "$*" >&2; exit 1; }

# ------------- Vivado env -------------
VIVADO_HOME="${VIVADO_HOME:-$HOME/tools/Xilinx/2025.2/Vivado}"
VIVADO_BIN="$VIVADO_HOME/bin"
SETTINGS="$VIVADO_HOME/settings64.sh"

if [[ -f "$SETTINGS" ]]; then
  # shellcheck disable=SC1091
  source "$SETTINGS"
else
  [[ -x "$VIVADO_BIN/xvlog" ]] || die "Vivado not found at $VIVADO_BIN"
  export PATH="$VIVADO_BIN:$PATH"
fi

command -v xvlog >/dev/null || die "xvlog not in PATH"
command -v xelab >/dev/null || die "xelab not in PATH"
command -v xsim  >/dev/null || die "xsim not in PATH"

# Xilinx precompiled simulation libraries to link
LIBS=(-L unisims_ver -L unimacro_ver -L xpm -L secureip)

# ------------- Args -------------
TESTCASE_NAME="${1:-plugin_core_tb}"   # e.g. tc_eth_sanity / tc_eth_plugin
MODE="${2:-gui}"                       # gui | cli
SNAPSHOT="${TESTCASE_NAME}_sim"

# ------------- Paths -------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RTL_DIR="$PROJ_ROOT/rtl"
TB_DIR="$PROJ_ROOT/sim/tb/testcases"
BFM_DIR="$PROJ_ROOT/sim/tb/BFM"

LOG_MAIN_DIR="$SCRIPT_DIR/logs"
LOG_DIR="$LOG_MAIN_DIR/$TESTCASE_NAME"
TMP_DIR="$LOG_MAIN_DIR/tmp"

mkdir -p "$LOG_DIR" "$TMP_DIR"

# Clean BEFORE creating new filelist
rm -rf "$LOG_MAIN_DIR/xsim.dir" "$LOG_MAIN_DIR/.Xil" 2>/dev/null || true
find "$TMP_DIR" -maxdepth 1 -type f \( -name "*.f" -o -name "*.list" \) -delete 2>/dev/null || true

# ------------- Filelist -------------
TB_FILELIST="$TMP_DIR/${TESTCASE_NAME}_files.f"
: > "$TB_FILELIST"

# RTL
[[ -d "$RTL_DIR" ]] || die "RTL dir missing: $RTL_DIR"

# -----------------------------------------------------------------------------
# Build file ordering:
#   1) RTL packages
#   2) TB packages
#   3) RTL non-package files
#   4) Common TB wrapper
#   5) BFMs
#   6) Testcase
#
# Notes:
#   - Do NOT compile glbl.v in xvlog filelist. We already add glbl at xelab.
#   - Keep all packages before any modules that import them.
# -----------------------------------------------------------------------------

PKG_LIST="$TMP_DIR/${TESTCASE_NAME}_pkgs.list"
TB_PKG_LIST="$TMP_DIR/${TESTCASE_NAME}_tb_pkgs.list"
ALL_LIST="$TMP_DIR/${TESTCASE_NAME}_all.list"

: > "$PKG_LIST"
: > "$TB_PKG_LIST"
: > "$ALL_LIST"

# RTL packages:
#   1) any SystemVerilog file under a directory named "pkg"
#   2) any file named "*_pkg.sv" anywhere in rtl/
find "$RTL_DIR" -type f -name "*.sv" -path "*/pkg/*" | sort -u >> "$PKG_LIST"
find "$RTL_DIR" -type f -name "*_pkg.sv" | sort -u >> "$PKG_LIST"
sort -u "$PKG_LIST" -o "$PKG_LIST"

# TB packages:
#   any file named "*_pkg.sv" under sim/tb/
find "$PROJ_ROOT/sim/tb" -type f -name "*_pkg.sv" | sort -u > "$TB_PKG_LIST"

# All RTL SV/V files
find "$RTL_DIR" -type f \( -name "*.sv" -o -name "*.v" \) | sort -u > "$ALL_LIST"

# 1) Emit RTL packages first
cat "$PKG_LIST" >> "$TB_FILELIST"

# 2) Emit TB packages next
cat "$TB_PKG_LIST" >> "$TB_FILELIST"

# 3) Emit RTL non-package files
comm -23 "$ALL_LIST" "$PKG_LIST" >> "$TB_FILELIST"

# 4) Common TB wrapper
TB_WRAPPER="$PROJ_ROOT/sim/tb/tb.sv"
[[ -f "$TB_WRAPPER" ]] || die "Missing TB wrapper: $TB_WRAPPER"
echo "$TB_WRAPPER" >> "$TB_FILELIST"

# 5) BFMs (optional)
if [[ -d "$BFM_DIR" ]]; then
  find "$BFM_DIR" -type f -name "*.sv" | sort -u >> "$TB_FILELIST"
fi

# 6) Testcase TB
TB_FILE="$TB_DIR/$TESTCASE_NAME/$TESTCASE_NAME.sv"
[[ -f "$TB_FILE" ]] || die "Testbench file not found: $TB_FILE"
echo "$TB_FILE" >> "$TB_FILELIST"

# ------------- Info -------------
log "Project root : $PROJ_ROOT"
log "RTL dir      : $RTL_DIR"
log "TB dir       : $TB_DIR"
log "TB filelist  : $TB_FILELIST"
log "Testcase     : $TESTCASE_NAME"
log "Mode         : $MODE"

# ------------- Compile -------------
xvlog -sv -d SIMULATION \
  -i "$PROJ_ROOT/sim/tb" \
  -i "$PROJ_ROOT/sim/tb/include" \
  "${LIBS[@]}" \
  -f "$TB_FILELIST" \
  -log "$LOG_DIR/xvlog.log" || {
    log "Compilation failed. See: $LOG_DIR/xvlog.log"
    exit 1
  }

# ------------- Elaborate -------------
log "Elaborating..."
xelab "$TESTCASE_NAME" glbl \
  --debug typical \
  --snapshot "$SNAPSHOT" \
  "${LIBS[@]}" \
  -log "$LOG_DIR/xelab.log" || {
    log "Elaboration failed. See: $LOG_DIR/xelab.log"
    exit 1
  }

# ------------- Run -------------
log "Launching XSIM..."
if [[ "$MODE" == "gui" ]]; then
  exec xsim "$SNAPSHOT" --gui
else
  TCL="${SCRIPT_DIR}/xsim.tcl"
  if [[ -f "$TCL" ]]; then
    exec xsim "$SNAPSHOT" --tclbatch "$TCL" -log "$LOG_DIR/xsim.log"
  else
    exec xsim "$SNAPSHOT" -runall -log "$LOG_DIR/xsim.log"
  fi
fi
