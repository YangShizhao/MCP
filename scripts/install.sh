#!/bin/bash
#==============================================================================
# MCP Offline Installer (Linux / macOS)
# Installs MCP tools from the unified deps/ structure.
# Usage: sudo bash install.sh [--target /opt/my-tools] [--no-path] [--no-claude]
#==============================================================================

set -e

TARGET_PATH="/opt/mcp-tools"
CONFIGURE_PATH=true
CONFIGURE_CLAUDE=true
CONFIGURE_CLINE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo ""; echo -e "${CYAN}>>> $1${NC}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET_PATH="$2"; shift 2 ;;
    --no-path) CONFIGURE_PATH=false; shift ;;
    --no-claude) CONFIGURE_CLAUDE=false; shift ;;
    --no-cline) CONFIGURE_CLINE=false; shift ;;
    --help|-h) echo "Usage: sudo bash install.sh [options]"; echo "  --target <path>  Install path (default: /opt/mcp-tools)"; echo "  --no-path        Skip PATH config"; echo "  --no-claude      Skip Claude Code config"; exit 0 ;;
    *) log_error "Unknown: $1"; exit 1 ;;
  esac
done

echo ""
echo -e "${MAGENTA}==============================================${NC}"
echo -e "${MAGENTA}|     MCP Tools - Offline Installer (Unix)     |${NC}"
echo -e "${MAGENTA}==============================================${NC}"
echo ""

# ---- 1. Locate bundle ----
log_step "1/6 Checking bundle..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR"
DEPS_DIR="$BUNDLE_DIR/deps"
TOOLS_DIR="$BUNDLE_DIR/tools"
DEPS_NPM="$DEPS_DIR/npm/node_modules"
DEPS_PIP="$DEPS_DIR/pip"
DEPS_RUNTIMES="$DEPS_DIR/runtimes"

HAS_PDF=false; HAS_OFFICE=false
[ -d "$DEPS_NPM/@sylphx/pdf-reader-mcp" ] && [ -d "$TOOLS_DIR/pdf-toolkit-mcp/dist" ] && HAS_PDF=true
[ -d "$TOOLS_DIR/mcp-office" ] && ls "$DEPS_PIP"/*.whl >/dev/null 2>&1 && HAS_OFFICE=true

if ! $HAS_PDF && ! $HAS_OFFICE; then
  log_error "Bundle incomplete: no tools found under deps/ or tools/"
  exit 1
fi
log_ok "Bundle OK (PDF: $HAS_PDF, Office: $HAS_OFFICE)"

# ---- 2. Check Node.js ----
log_step "2/6 Checking Node.js..."
NODE_EXE=""; NODE_SOURCE=""
BUNDLED_NODE_DIR="$DEPS_RUNTIMES/nodejs"
BUNDLED_NODE="$BUNDLED_NODE_DIR/bin/node"
NODE_REQ="22.13.0"; NODE_MAJOR_REQ=22

SYS_NODE_OK=false
if command -v node &>/dev/null; then
  SYS_VER=$(node --version 2>&1)
  SYS_MAJOR=$(echo "$SYS_VER" | sed 's/v//' | cut -d'.' -f1)
  [ "$SYS_MAJOR" -ge "$NODE_MAJOR_REQ" ] && SYS_NODE_OK=true
fi

if $SYS_NODE_OK; then
  NODE_EXE="node"; NODE_SOURCE="system"
  log_ok "System Node.js $SYS_VER meets requirement (>= $NODE_REQ)"
elif [ -x "$BUNDLED_NODE" ]; then
  sudo mkdir -p "$TARGET_PATH/deps/runtimes"
  sudo cp -r "$BUNDLED_NODE_DIR" "$TARGET_PATH/deps/runtimes/"
  NODE_EXE="$TARGET_PATH/deps/runtimes/nodejs/bin/node"; NODE_SOURCE="bundled"
  NODE_VER=$("$NODE_EXE" --version 2>&1)
  log_ok "Using bundled Node.js $NODE_VER"
elif command -v node &>/dev/null; then
  NODE_EXE="node"; NODE_SOURCE="system(outdated)"
  log_warn "System Node.js below $NODE_REQ; may not work"
else
  log_error "Node.js >= $NODE_REQ not found and no bundled runtime"; exit 1
fi

# ---- 3. Check Python ----
PYTHON_EXE=""; PYTHON_SOURCE=""
BUNDLED_PY_DIR="$DEPS_RUNTIMES/python"
BUNDLED_PY="$BUNDLED_PY_DIR/bin/python3"
PY_REQ="3.11"

if $HAS_OFFICE; then
  SYS_PY_OK=false
  if command -v python3 &>/dev/null; then
    SYS_PY_VER=$(python3 --version 2>&1 | sed 's/Python //')
    SYS_PY_M=$(echo "$SYS_PY_VER" | cut -d'.' -f1)
    SYS_PY_m=$(echo "$SYS_PY_VER" | cut -d'.' -f2)
    { [ "$SYS_PY_M" -gt 3 ] || { [ "$SYS_PY_M" -eq 3 ] && [ "$SYS_PY_m" -ge 11 ]; }; } && SYS_PY_OK=true
  fi

  if $SYS_PY_OK; then
    PYTHON_EXE="python3"; PYTHON_SOURCE="system"
    log_ok "System Python $SYS_PY_VER meets requirement (>= $PY_REQ)"
  elif [ -x "$BUNDLED_PY" ]; then
    sudo mkdir -p "$TARGET_PATH/deps/runtimes"
    sudo cp -r "$BUNDLED_PY_DIR" "$TARGET_PATH/deps/runtimes/"
    PYTHON_EXE="$TARGET_PATH/deps/runtimes/python/bin/python3"; PYTHON_SOURCE="bundled"
    log_ok "Using bundled Python"
  elif command -v python3 &>/dev/null; then
    PYTHON_EXE="python3"; PYTHON_SOURCE="system(outdated)"
    log_warn "System Python below $PY_REQ; Office tools may not work"
  else
    log_warn "Python >= $PY_REQ not found; Office tools skipped"
    HAS_OFFICE=false
  fi
fi

# ---- 4. Install files ----
log_step "3/6 Installing to $TARGET_PATH ..."
sudo mkdir -p "$TARGET_PATH"

# Copy unified deps
if [ -d "$DEPS_DIR" ]; then
  sudo rm -rf "$TARGET_PATH/deps" 2>/dev/null || true
  sudo cp -r "$DEPS_DIR" "$TARGET_PATH/"
  log_ok "Deps installed to $TARGET_PATH/deps"
fi

# Copy tools
if [ -d "$TOOLS_DIR" ]; then
  sudo rm -rf "$TARGET_PATH/tools" 2>/dev/null || true
  sudo cp -r "$TOOLS_DIR" "$TARGET_PATH/"
  log_ok "Tools installed to $TARGET_PATH/tools"
fi

# Copy bin, config
for item in bin config docs; do
  [ -e "$BUNDLE_DIR/$item" ] || continue
  sudo rm -rf "$TARGET_PATH/$item" 2>/dev/null || true
  sudo cp -r "$BUNDLE_DIR/$item" "$TARGET_PATH/"
done
sudo chmod -R 755 "$TARGET_PATH/bin" 2>/dev/null || true
sudo chmod +x "$TARGET_PATH/bin/"*.sh 2>/dev/null || true

log_ok "All files installed"

# ---- 5. Install Python deps from deps/pip/ ----
if $HAS_OFFICE && [ -n "$PYTHON_EXE" ]; then
  log_step "4/6 Installing Office MCP tools from deps/pip/..."
  WHEELS_DIR="$TARGET_PATH/deps/pip"
  OFFICE_SRC="$TARGET_PATH/tools/mcp-office"

  log_info "Installing Python deps from local wheels..."
  $PYTHON_EXE -m pip install --no-index --find-links "$WHEELS_DIR" fastmcp python-docx python-pptx openpyxl Pillow 2>&1 | tail -5

  log_info "Installing mcp-office packages..."
  for pkg in shared wordmcp pptmcp excelmcp; do
    [ -d "$OFFICE_SRC/$pkg" ] || continue
    $PYTHON_EXE -m pip install --no-index --find-links "$WHEELS_DIR" -e "$OFFICE_SRC/$pkg" 2>&1 | tail -1
  done
  log_ok "Office tools installed"

  log_info "Verifying..."
  for tool in wordmcp pptmcp excelmcp; do
    printf "  %-18s ... " "$tool"
    $PYTHON_EXE -c "import ${tool}.server" 2>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}WARN${NC}"
  done
else
  log_step "4/6 Skipping Office tools"
fi

# ---- 6. Configure AI tools + PATH ----
log_step "5/6 Configuring AI tool MCP settings..."

if $CONFIGURE_CLAUDE; then
  CCFG="$HOME/.claude.json"
  # Build config
  python3 -c "
import json, os
cfg = {}
try:
    with open('$CCFG') as f: cfg = json.load(f)
except: pass
cfg.setdefault('mcpServers', {})
" 2>/dev/null || true

  if $HAS_PDF; then
    python3 -c "
import json
cfg = {}
try:
    with open('$CCFG') as f: cfg = json.load(f)
except: pass
cfg['mcpServers']['pdf-reader'] = {'command': '$TARGET_PATH/bin/pdf-reader.sh', 'description': 'PDF read, search, extract'}
cfg['mcpServers']['pdf-toolkit'] = {'command': '$TARGET_PATH/bin/pdf-toolkit.sh', 'description': 'PDF create, edit, merge'}
with open('$CCFG', 'w') as f: json.dump(cfg, f, indent=2); f.write('\n')
" 2>/dev/null
  fi
  if $HAS_OFFICE && [ -n "$PYTHON_EXE" ]; then
    python3 -c "
import json
cfg = {}
try:
    with open('$CCFG') as f: cfg = json.load(f)
except: pass
cfg['mcpServers']['word'] = {'command': '$TARGET_PATH/bin/wordmcp.sh', 'env': {'WORD_ALLOWLIST_ROOTS': '/home', 'WORD_ENABLE_WRITE': 'true'}, 'description': 'Word docs - 51 tools'}
cfg['mcpServers']['ppt'] = {'command': '$TARGET_PATH/bin/pptmcp.sh', 'env': {'PPT_ALLOWLIST_ROOTS': '/home', 'PPT_ENABLE_WRITE': 'true'}, 'description': 'PowerPoint - 48 tools'}
cfg['mcpServers']['excel'] = {'command': '$TARGET_PATH/bin/excelmcp.sh', 'env': {'EXCEL_ALLOWLIST_ROOTS': '/home', 'EXCEL_ENABLE_WRITE': 'true'}, 'description': 'Excel - 65 tools'}
with open('$CCFG', 'w') as f: json.dump(cfg, f, indent=2); f.write('\n')
" 2>/dev/null
  fi
  log_ok "Claude Code config: $CCFG"
fi

# ---- PATH ----
if $CONFIGURE_PATH; then
  log_step "6/6 Configuring PATH..."
  for prof in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$prof" ] && ! grep -q "$TARGET_PATH/bin" "$prof" 2>/dev/null; then
      echo "" >> "$prof"
      echo "# MCP Tools" >> "$prof"
      echo "export PATH=\"\$PATH:$TARGET_PATH/bin\"" >> "$prof"
      log_ok "Added to $prof"
    fi
  done
  for tool in pdf-reader pdf-toolkit wordmcp pptmcp excelmcp; do
    [ -x "$TARGET_PATH/bin/${tool}.sh" ] && sudo ln -sf "$TARGET_PATH/bin/${tool}.sh" "/usr/local/bin/${tool}" 2>/dev/null || true
  done
fi

# ---- Done ----
echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}|          INSTALL COMPLETE!                   |${NC}"
echo -e "${GREEN}|----------------------------------------------|${NC}"
echo -e "${GREEN}|  Path: $TARGET_PATH${NC}"
echo -e "${GREEN}|----------------------------------------------|${NC}"
echo -e "${GREEN}|  Deps cache: deps/                           |${NC}"
echo -e "${GREEN}|    deps/npm/      - Node.js dependencies     |${NC}"
echo -e "${GREEN}|    deps/pip/      - Python wheels            |${NC}"
echo -e "${GREEN}|    deps/runtimes/ - Node.js + Python         |${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
