#!/bin/bash
#==============================================================================
# MCP Offline Installer (Linux / macOS)
# Installs MCP tools from the unified deps/ structure.
# Usage: sudo bash install.sh [--target /opt/my-tools] [--no-path] [--no-claude]
#==============================================================================

set -e

TARGET_PATH="$HOME/mcp-tools"
CONFIGURE_PATH=true
CONFIGURE_CLAUDE=true
CONFIGURE_CLINE=true
CONFIGURE_CODEX=true
CONFIGURE_DSH=true

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
    --no-codex) CONFIGURE_CODEX=false; shift ;;
    --no-dsh) CONFIGURE_DSH=false; shift ;;
    --help|-h) echo "Usage: bash install.sh [options]"; echo "  --target <path>  Install path (default: $HOME/mcp-tools)"; echo "  --no-path        Skip PATH config"; echo "  --no-claude      Skip Claude Code config"; echo "  --no-cline       Skip Cline config"; echo "  --no-codex       Skip Codex config"; echo "  --no-dsh         Skip DeepSeek Harness config"; exit 0 ;;
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
  PY_MINOR_MIN=11
  py_ok() {  # $1 = 解释器路径/名称，判断版本是否 >= 3.11
    local v major minor
    v=$("$1" --version 2>&1 | sed 's/^Python //')
    major=$(echo "$v" | cut -d'.' -f1)
    minor=$(echo "$v" | cut -d'.' -f2)
    case "$major" in ''|*[!0-9]*) return 1 ;; esac
    case "$minor" in ''|*[!0-9]*) return 1 ;; esac
    [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge "$PY_MINOR_MIN" ]; }
  }

  # 系统 python3 常常是 3.10 或更低（mcp-office 要求 >= 3.11）：
  # 依次尝试常见版本化解释器与 conda 环境，最后一个可用的作为兜底。
  PYTHON_EXE=""; PYTHON_SOURCE=""
  for cand in python3 python3.13 python3.12 python3.11 \
              "$HOME/miniforge3/bin/python3" "$HOME/anaconda3/bin/python3" \
              "$HOME/miniconda3/bin/python3" \
              /usr/local/bin/python3.12 /usr/local/bin/python3.11 \
              /opt/conda/bin/python3; do
    if command -v "$cand" >/dev/null 2>&1 && py_ok "$cand"; then
      PYTHON_EXE="$cand"; PYTHON_SOURCE="system"
      break
    fi
  done

  if [ -n "$PYTHON_EXE" ]; then
    log_ok "Python $("$PYTHON_EXE" --version 2>&1 | sed 's/Python //') meets requirement (>= $PY_REQ) [$PYTHON_EXE]"
  elif [ -x "$BUNDLED_PY" ]; then
    sudo mkdir -p "$TARGET_PATH/deps/runtimes"
    sudo cp -r "$BUNDLED_PY_DIR" "$TARGET_PATH/deps/runtimes/"
    PYTHON_EXE="$TARGET_PATH/deps/runtimes/python/bin/python3"; PYTHON_SOURCE="bundled"
    log_ok "Using bundled Python"
  elif command -v python3 &>/dev/null; then
    PYTHON_EXE="python3"; PYTHON_SOURCE="system(outdated)"
    log_warn "System Python ($(python3 --version 2>&1)) below $PY_REQ; Office tools may not work"
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

  log_info "Installing Office runtime deps from local wheels..."
  # Only runtime deps — PYTHONPATH handles imports (no pip install -e needed)
  $PYTHON_EXE -m pip install --no-index --find-links "$WHEELS_DIR" fastmcp python-docx python-pptx openpyxl Pillow 2>&1 | tail -5
  log_ok "Office runtime deps installed (PYTHONPATH mode)"

  PYTHONPATH="$OFFICE_SRC/shared/src:$OFFICE_SRC/wordmcp/src:$OFFICE_SRC/pptmcp/src:$OFFICE_SRC/excelmcp/src"
  export PYTHONPATH
  log_info "Verifying (首次导入 fastmcp 可能需要十几秒)..."
  for tool in wordmcp pptmcp excelmcp; do
    printf "  %-18s ... " "$tool"
    err=$($PYTHON_EXE -c "import ${tool}.server" 2>&1)
    if [ $? -eq 0 ]; then echo -e "${GREEN}OK${NC}"; else echo -e "${YELLOW}WARN${NC}"; [ -n "$err" ] && echo -e "         ${err}" | head -3; fi
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

# ---- Codex CLI (TOML config) ----
if $CONFIGURE_CODEX; then
  CODEX_DIR="$HOME/.codex"
  CODEX_FILE="$CODEX_DIR/config.toml"
  mkdir -p "$CODEX_DIR"

  EXISTING=""
  [ -f "$CODEX_FILE" ] && EXISTING=$(cat "$CODEX_FILE")

  NEW_BLOCKS=""
  NEW_COUNT=0

  add_codex_server() {
    local name="$1" cmd="$2" envline="$3"
    if echo "$EXISTING" | grep -q "\[mcp_servers\.$name\]"; then return; fi
    NEW_BLOCKS="${NEW_BLOCKS}
[mcp_servers.$name]
command = \"$cmd\""
    [ -n "$envline" ] && NEW_BLOCKS="${NEW_BLOCKS}
env = { $envline }"
    NEW_BLOCKS="${NEW_BLOCKS}
"
    NEW_COUNT=$((NEW_COUNT + 1))
  }

  if $HAS_PDF; then
    add_codex_server "pdf-reader"  "$TARGET_PATH/bin/pdf-reader.sh"  ""
    add_codex_server "pdf-toolkit" "$TARGET_PATH/bin/pdf-toolkit.sh" ""
  fi
  if $HAS_OFFICE && [ -n "$PYTHON_EXE" ]; then
    add_codex_server "word"  "$TARGET_PATH/bin/wordmcp.sh"  "WORD_ALLOWLIST_ROOTS = \"$HOME\", WORD_ENABLE_WRITE = \"true\""
    add_codex_server "ppt"   "$TARGET_PATH/bin/pptmcp.sh"   "PPT_ALLOWLIST_ROOTS = \"$HOME\", PPT_ENABLE_WRITE = \"true\""
    add_codex_server "excel" "$TARGET_PATH/bin/excelmcp.sh" "EXCEL_ALLOWLIST_ROOTS = \"$HOME\", EXCEL_ENABLE_WRITE = \"true\""
  fi

  if [ "$NEW_COUNT" -gt 0 ]; then
    {
      echo ""
      echo "# --- MCP Tools (added by install.sh) ---"
      echo "$NEW_BLOCKS"
    } >> "$CODEX_FILE"
    log_ok "Codex: +$NEW_COUNT tool(s) -> $CODEX_FILE"
  else
    log_info "Codex config already up to date"
  fi
fi

# ---- DeepSeek Harness (YAML loader patch) ----
# dsh keeps one home-level patch layer at $DSH_HOME/cordis.patch.yml that is
# applied over EVERY profile (web / headless / sdk / acp / custom). Each MCP
# server is one insert row naming the '@deepseek-ai/dsh-mcp-client' plugin, and
# its tools then appear as mcp__<serverName>__<tool>.
if $CONFIGURE_DSH; then
  DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
  DSH_PATCH="$DSH_HOME_DIR/cordis.patch.yml"
  mkdir -p "$DSH_HOME_DIR" 2>/dev/null || true
  [ -f "$DSH_PATCH" ] && cp "$DSH_PATCH" "$DSH_PATCH.bak" 2>/dev/null || true

  DSH_ADDED=$(DSH_PATCH="$DSH_PATCH" TARGET_PATH="$TARGET_PATH" HOME_DIR="$HOME" \
    HAS_PDF="$HAS_PDF" HAS_OFFICE="$HAS_OFFICE" OFFICE_OK="$( [ -n "$PYTHON_EXE" ] && echo true || echo false )" \
    python3 - <<'DSHPY'
import os, re, sys

patch = os.environ["DSH_PATCH"]
target = os.environ["TARGET_PATH"]
home = os.environ["HOME_DIR"]
has_pdf = os.environ["HAS_PDF"] == "true"
has_office = os.environ["HAS_OFFICE"] == "true" and os.environ["OFFICE_OK"] == "true"

SERVERS = []
if has_pdf:
    SERVERS += [
        ("pdf-reader", "PDF read, search, extract, render", {}),
        ("pdf-toolkit", "PDF create, edit, merge, split, forms, encrypt", {}),
    ]
if has_office:
    SERVERS += [
        ("word", "Word docs - 51 tools",
         {"WORD_ALLOWLIST_ROOTS": home, "WORD_ENABLE_WRITE": "true"}),
        ("ppt", "PowerPoint - 48 tools",
         {"PPT_ALLOWLIST_ROOTS": home, "PPT_ENABLE_WRITE": "true"}),
        ("excel", "Excel - 65 tools",
         {"EXCEL_ALLOWLIST_ROOTS": home, "EXCEL_ENABLE_WRITE": "true"}),
    ]

try:
    with open(patch, encoding="utf-8") as f:
        text = f.read()
except FileNotFoundError:
    text = ""

if not text.strip():
    text = "# DeepSeek Harness user patch layer ($DSH_HOME/cordis.patch.yml).\n# Applies to every dsh profile; MCP rows below are maintained by MCP Tools install.sh.\n"

# A generated template may leave the empty-root placeholder behind; drop it
# before inserting rows, otherwise the document would hold two root nodes.
text = re.sub(r"(?m)^\s*\[\s*\]\s*$\n?", "", text)

def block(name, desc, env, indent="    "):
    cmd = "%s/bin/%s.sh" % (target, {
        "pdf-reader": "pdf-reader", "pdf-toolkit": "pdf-toolkit",
        "word": "wordmcp", "ppt": "pptmcp", "excel": "excelmcp"}[name])
    lines = [
        "%s- id: mcp-%s" % (indent, name),
        "%s  name: '@deepseek-ai/dsh-mcp-client'" % indent,
        "%s  config:" % indent,
        "%s    serverName: %s" % (indent, name),
        "%s    transport: stdio" % indent,
        "%s    command: %s" % (indent, cmd),
    ]
    if env:
        lines.append("%s    env:" % indent)
        for key, value in env.items():
            lines.append('%s      %s: "%s"' % (indent, key, value))
    lines.append("%s    # %s" % (indent, desc))
    return "\n".join(lines) + "\n"

added = []
for name, desc, env in SERVERS:
    if re.search(r"(?m)^\s*-\s*id:\s*mcp-%s\s*$" % re.escape(name), text):
        continue
    added.append(block(name, desc, env))

if not added:
    print(0)
    sys.exit(0)

tail = "# --- MCP Tools (added by install.sh) ---\n- insert:\n" + "".join(added)
if not text.endswith("\n"):
    text += "\n"
text += tail

with open(patch, "w", encoding="utf-8") as f:
    f.write(text)

print(len(added))
DSHPY
  ) || DSH_ADDED=""

  if [ "${DSH_ADDED:-0}" = "0" ] && [ -f "$DSH_PATCH" ]; then
    log_info "DeepSeek Harness config already up to date"
  elif [ -n "${DSH_ADDED:-}" ]; then
    log_ok "DeepSeek Harness: +$DSH_ADDED tool(s) -> $DSH_PATCH"
    log_info "Tools appear as mcp__<name>__<tool> after the next dsh start"
  else
    log_warn "DeepSeek Harness: python3 unavailable, config skipped"
  fi
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
