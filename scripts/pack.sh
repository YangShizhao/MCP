#!/bin/bash
#==============================================================================
# MCP 离线打包脚本
# 用途: 在有网络的环境中运行，将本项目所有 MCP 工具及依赖打包为离线安装包
# 用法: bash scripts/pack.sh [--skip-nodejs] [--skip-python] [--skip-pdf] [--skip-office] [--platform win|linux|mac]
# 默认打包全部工具 + 全部运行时，用 --skip-* 排除不需要的
#==============================================================================

set -e

# ---- 配置 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/mcp-offline-bundle"
CACHE_DIR="$PROJECT_DIR/.cache"

# 统一依赖缓存子目录
CACHE_NPM="$CACHE_DIR/npm"         # npm node_modules
CACHE_PIP="$CACHE_DIR/pip"         # pip wheel 文件
CACHE_RUNTIMES="$CACHE_DIR/runtimes"  # Node.js / Python 便携版
CACHE_GIT="$CACHE_DIR/git"         # Git 仓库

# Bundle 中的统一依赖目录（安装时从此目录安装）
BUNDLE_DEPS="$BUNDLE_DIR/deps"
BUNDLE_TOOLS="$BUNDLE_DIR/tools"

# ---- 固定版本（保证可复现的构建） ----
NODE_VERSION="22.14.0"
PYTHON_VERSION="3.11.9"

# PDF 工具版本
PDF_READER_VERSION="3.0.10"          # @sylphx/pdf-reader-mcp
PDF_TOOLKIT_VERSION="2.0.0"          # pdf-toolkit-mcp version (package.json)
PDF_TOOLKIT_REF="main"                # git branch (no version tags)

# Office 工具版本（mcp-office 子包）
MCP_OFFICE_WORD_VERSION="0.4.0"
MCP_OFFICE_PPT_VERSION="0.5.0"
MCP_OFFICE_EXCEL_VERSION="0.6.0"

# Python 依赖固定版本
PIP_FASTMCP_VERSION="3.2.0"
PIP_PYDOCX_VERSION="1.1.2"
PIP_PYPPTX_VERSION="1.0.2"
PIP_OPENPYXL_VERSION="3.1.5"
PIP_PILLOW_VERSION="11.0.0"

# ---- 开关 ----
SKIP_NODEJS=false
SKIP_PYTHON=false
SKIP_PDF=false
SKIP_OFFICE=false
NO_CACHE=false
PLATFORM="win"

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_cache() { echo -e "${BLUE}[CACHE]${NC} $1"; }

# ---- 统一缓存辅助函数 ----

# 确保缓存目录存在
init_cache() {
  mkdir -p "$CACHE_NPM" "$CACHE_PIP" "$CACHE_RUNTIMES" "$CACHE_GIT"
}

# 缓存文件（下载到 runtimes 缓存目录）
cache_file() {
  local name="$1"
  local url="$2"
  local dest="$CACHE_RUNTIMES/$name"
  if [ -f "$dest" ] && ! $NO_CACHE; then
    log_cache "命中: $name"
    echo "$dest"
    return 0
  fi
  log_info "下载: $name"
  if command -v curl &> /dev/null; then
    curl -L -o "$dest" "$url" --progress-bar
  elif command -v wget &> /dev/null; then
    wget -O "$dest" "$url" --show-progress
  else
    log_error "需要 curl 或 wget"
    exit 1
  fi
  log_cache "已缓存: $name (runtimes)"
  echo "$dest"
}

# 缓存 Git 仓库（浅克隆到 git 缓存目录，之后复用）
cache_git() {
  local name="$1"
  local url="$2"
  local ref="${3:-main}"
  local dest="$CACHE_GIT/$name"
  if [ -d "$dest/.git" ] && ! $NO_CACHE; then
    log_cache "命中: $name (git)"
    echo "$dest"
    return 0
  fi
  log_info "克隆: $url (ref: $ref)"
  rm -rf "$dest"
  git clone --depth 1 --branch "$ref" "$url" "$dest" 2>&1 | while IFS= read -r line; do
    echo "         $line"
  done
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log_warn "分支 $ref 不存在，尝试默认分支..."
    git clone --depth 1 "$url" "$dest" 2>&1 | while IFS= read -r line; do
      echo "         $line"
    done
  fi
  log_cache "已缓存: $name (git)"
  echo "$dest"
}

# npm 缓存：复用 node_modules
cache_npm_modules() {
  if $NO_CACHE; then return 1; fi
  if [ -d "$CACHE_NPM/node_modules/@sylphx/pdf-reader-mcp" ]; then
    log_cache "命中: npm node_modules"
    return 0
  fi
  return 1
}

# pip 缓存：复用 wheel 文件
restore_pip_cache() {
  local dest="$1"
  if ! $NO_CACHE && ls "$CACHE_PIP"/*.whl 2>/dev/null | head -1 | grep -q .; then
    log_cache "命中: pip wheels (共 $(ls "$CACHE_PIP"/*.whl 2>/dev/null | wc -l) 个)"
    cp "$CACHE_PIP"/*.whl "$dest/" 2>/dev/null || true
    return 0
  fi
  return 1
}

save_pip_cache() {
  local src="$1"
  if ! $NO_CACHE; then
    cp "$src"/*.whl "$CACHE_PIP/" 2>/dev/null || true
    log_cache "已缓存: pip wheels → $CACHE_PIP"
  fi
}

# ---- 参数解析 ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-nodejs) SKIP_NODEJS=true; shift ;;
    --skip-python) SKIP_PYTHON=true; shift ;;
    --skip-pdf) SKIP_PDF=true; shift ;;
    --skip-office) SKIP_OFFICE=true; shift ;;
    --no-cache) NO_CACHE=true; shift ;;
    --refresh) NO_CACHE=true; shift ;;  # alias for --no-cache
    --platform) PLATFORM="$2"; shift 2 ;;
    --help|-h)
      echo "用法: bash scripts/pack.sh [选项]"
      echo ""
      echo "默认打包全部工具（PDF + Office）和全部运行时（Node.js + Python）。"
      echo "用 --skip-* 排除不需要的。"
      echo ""
      echo "选项:"
      echo "  --skip-nodejs      不打包 Node.js 运行时"
      echo "  --skip-python      不打包 Python 嵌入式版本"
      echo "  --skip-pdf         跳过 PDF 工具打包"
      echo "  --skip-office      跳过 Office 工具打包（Word/PPT/Excel）"
      echo "  --no-cache         忽略缓存，强制重新下载所有依赖"
      echo "  --platform <平台>   目标平台: win (默认), linux, mac"
      echo "  --help, -h          显示帮助"
      exit 0
      ;;
    *) log_error "未知参数: $1"; exit 1 ;;
  esac
done

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       MCP 离线安装包 - 打包工具              ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  目标平台:    $PLATFORM"
echo "║  PDF 工具:    $( $SKIP_PDF && echo '跳过' || echo '打包' )"
echo "║  Office 工具: $( $SKIP_OFFICE && echo '跳过' || echo '打包' )"
echo "║  Node.js:     $( $SKIP_NODEJS && echo '跳过' || echo '打包' )"
echo "║  Python:      $( $SKIP_PYTHON && echo '跳过' || echo '打包' )"
echo "║  Node 版本:   v$NODE_VERSION"
echo "║  Python 版本: $PYTHON_VERSION"
echo "║  缓存:        $( $NO_CACHE && echo '禁用' || echo '启用' )"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ---- 1. 环境检查 ----
log_info "检查打包环境..."

if ! command -v node &> /dev/null; then
  log_error "未找到 Node.js，请先安装 Node.js >= 22"
  exit 1
fi
NODE_VER=$(node -v)
NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d'.' -f1)
log_ok "Node.js: $NODE_VER"

# 检查 Node 主版本号是否满足 pdf-reader-mcp 的最低要求 (>=22)
if [ "$NODE_MAJOR" -lt 22 ]; then
  log_warn "Node.js $NODE_VER 低于 pdf-reader-mcp 要求的 >= 22.13.0"
  log_warn "打包将继续，但 pdf-reader-mcp 在目标机器上可能无法正常运行"
  log_warn "建议升级 Node.js 到 v22+。Node.js v$NODE_VERSION 将默认被打包。"
fi

if ! command -v npm &> /dev/null; then
  log_error "未找到 npm"
  exit 1
fi
NPM_VER=$(npm -v)
log_ok "npm: v$NPM_VER"

if ! command -v git &> /dev/null; then
  log_error "未找到 git，pdf-toolkit-mcp 需要从 GitHub 克隆"
  exit 1
fi
log_ok "git: $(git --version | cut -d' ' -f3)"

if ! $SKIP_OFFICE; then
  if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    log_error "未找到 Python >= 3.11，mcp-office 需要 Python"
    log_error "请安装 Python 或使用 --skip-office 跳过 Office 工具"
    exit 1
  fi
  PYTHON_EXE=$(command -v python3 || command -v python)
  PYTHON_VER=$($PYTHON_EXE --version 2>&1 | cut -d' ' -f2)
  log_ok "Python: $PYTHON_VER"

  if ! $PYTHON_EXE -m pip --version &> /dev/null; then
    log_error "pip 不可用"
    exit 1
  fi
  log_ok "pip: $($PYTHON_EXE -m pip --version | cut -d' ' -f2)"
else
  PYTHON_EXE=""
fi

# ---- 2. 清理并创建构建目录 ----
log_info "准备构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUNDLE_DIR"/{bin,config,docs}
mkdir -p "$BUNDLE_DEPS"/{npm,pip,runtimes}
mkdir -p "$BUNDLE_TOOLS"

# ---- 3. 安装 @sylphx/pdf-reader-mcp (npm 包) ----
if ! $SKIP_PDF; then
log_info "安装 @sylphx/pdf-reader-mcp (从 npm)..."

# 创建临时工作区
WORK_DIR="$BUILD_DIR/_workspace"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 优先使用缓存的 node_modules
if cache_npm_modules; then
  cp -r "$CACHE_NPM/node_modules" "$WORK_DIR/"
  log_info "从缓存复用 node_modules，跳过 npm install"
else
  # 初始化 package.json 并安装
  cat > package.json << 'PKGJSON'
{
  "name": "mcp-offline-bundle",
  "private": true,
  "type": "module"
}
PKGJSON

  log_info "下载 @sylphx/pdf-reader-mcp@$PDF_READER_VERSION 及所有依赖..."
  npm install "@sylphx/pdf-reader-mcp@$PDF_READER_VERSION" --legacy-peer-deps 2>&1 | while IFS= read -r line; do
    echo "         $line"
  done

  # 缓存 node_modules 供下次复用
  if ! $NO_CACHE; then
    rm -rf "$CACHE_NPM/node_modules"
    cp -r node_modules "$CACHE_NPM/"
    log_cache "已缓存: npm node_modules → $CACHE_NPM"
  fi
fi

# 复制 node_modules 到 bundle 统一依赖目录
cp -r node_modules "$BUNDLE_DEPS/npm/"
log_ok "@sylphx/pdf-reader-mcp v$(node -e "console.log(require('$WORK_DIR/node_modules/@sylphx/pdf-reader-mcp/package.json').version)") 已下载"
log_info "  -> 依赖包数量: $(ls "$BUNDLE_DEPS/npm/node_modules" | wc -l)"

# ---- 4. 克隆并构建 pdf-toolkit-mcp (Git 仓库) ----
log_info "获取 pdf-toolkit-mcp v$PDF_TOOLKIT_VERSION (从 GitHub, ref: $PDF_TOOLKIT_REF)..."

cd "$WORK_DIR"
rm -rf pdf-toolkit-mcp

# 使用缓存加速 Git 克隆
cache_git "pdf-toolkit-mcp" "https://github.com/beepboop2025/pdf-toolkit-mcp.git" "$PDF_TOOLKIT_REF"
cp -r "$CACHE_DIR/pdf-toolkit-mcp" pdf-toolkit-mcp

cd pdf-toolkit-mcp

log_info "安装 pdf-toolkit-mcp 依赖..."
npm install --legacy-peer-deps 2>&1 | while IFS= read -r line; do
  echo "         $line"
done

log_info "编译 pdf-toolkit-mcp..."
npm run build 2>&1 | while IFS= read -r line; do
  echo "         $line"
done

# 将 pdf-toolkit-mcp 整体复制到 bundle（但复用共享的 node_modules）
TOOLKIT_DIR="$BUNDLE_TOOLS/pdf-toolkit-mcp"
mkdir -p "$TOOLKIT_DIR"
cp -r dist "$TOOLKIT_DIR/"
cp package.json "$TOOLKIT_DIR/"

# 将 pdf-toolkit-mcp 的额外依赖合并到共享 node_modules
# (pdf-reader-mcp 可能已包含部分相同依赖，这里做去重合并)
SHARED_MODULES="$BUNDLE_DEPS/npm/node_modules"
for dep_dir in node_modules/*/; do
  dep_name=$(basename "$dep_dir")
  if [ ! -d "$SHARED_MODULES/$dep_name" ]; then
    cp -r "$dep_dir" "$SHARED_MODULES/"
  fi
done
# 处理 scoped packages (@xxx/yyy)
for scope_dir in node_modules/@*/; do
  [ -d "$scope_dir" ] || continue
  scope_name=$(basename "$scope_dir")
  for dep_dir in "$scope_dir"/*/; do
    [ -d "$dep_dir" ] || continue
    dep_name=$(basename "$dep_dir")
    if [ ! -d "$SHARED_MODULES/@$scope_name/$dep_name" ]; then
      mkdir -p "$SHARED_MODULES/@$scope_name"
      cp -r "$dep_dir" "$SHARED_MODULES/@$scope_name/"
    fi
  done
done

log_ok "pdf-toolkit-mcp v$(node -e "console.log(require('$TOOLKIT_DIR/package.json').version)") 已构建"
fi   # end of SKIP_PDF guard

# ---- 4.5. mcp-office (Python) 离线打包 ----
if ! $SKIP_OFFICE; then
  log_info "获取 mcp-office (从 GitHub)..."
  cd "$WORK_DIR"
  rm -rf mcp-office

  # 使用缓存加速 Git 克隆
  cache_git "mcp-office" "https://github.com/dosev-ai/mcp-office.git" "main"
  cp -r "$CACHE_DIR/mcp-office" mcp-office

  cd mcp-office

  OFFICE_SRC_DIR="$BUNDLE_TOOLS/mcp-office"
  mkdir -p "$OFFICE_SRC_DIR"
  cp -r wordmcp pptmcp excelmcp shared "$OFFICE_SRC_DIR/"
  cp README.md "$OFFICE_SRC_DIR/" 2>/dev/null || true

  # 下载所有 pip 依赖为 wheel 包（优先使用统一缓存）
  log_info "下载 Python 依赖（固定版本，使用缓存）..."
  WHEELS_DIR="$BUNDLE_DEPS/pip"
  mkdir -p "$WHEELS_DIR"

  cd "$WORK_DIR/mcp-office"

  # 先安装 shared 包（pptmcp 依赖它）
  $PYTHON_EXE -m pip install -e ./shared --quiet 2>&1 | tail -1

  # 从统一缓存恢复已有 wheel
  restore_pip_cache "$WHEELS_DIR"

  # 固定版本的 pip 依赖列表
  PIP_PACKAGES=(
    "fastmcp==$PIP_FASTMCP_VERSION"
    "python-docx==$PIP_PYDOCX_VERSION"
    "python-pptx==$PIP_PYPPTX_VERSION"
    "openpyxl==$PIP_OPENPYXL_VERSION"
    "Pillow==$PIP_PILLOW_VERSION"
  )

  # 检查并下载缺失的包
  for pkg_spec in "${PIP_PACKAGES[@]}"; do
    pkg_name=$(echo "$pkg_spec" | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]')
    pkg_name="${pkg_name//-/_}"
    if ! $NO_CACHE && ls "$WHEELS_DIR"/${pkg_name}*.whl 2>/dev/null | head -1 | grep -q .; then
      log_cache "命中: $pkg_spec"
      continue
    fi
    log_info "  下载: $pkg_spec"
    $PYTHON_EXE -m pip download -d "$WHEELS_DIR" "$pkg_spec" 2>&1 | while IFS= read -r line; do
      echo "         $line"
    done
  done

  # 下载各子包的传递依赖
  for pkg_dir in wordmcp pptmcp excelmcp; do
    log_info "  下载 $pkg_dir 传递依赖..."
    $PYTHON_EXE -m pip download \
      -d "$WHEELS_DIR" \
      "$WORK_DIR/mcp-office/$pkg_dir" \
      2>&1 | while IFS= read -r line; do
      echo "         $line"
    done
  done

  # 保存到统一缓存
  save_pip_cache "$WHEELS_DIR"

  WHEEL_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | wc -l)
  log_ok "Python 依赖已下载 ($WHEEL_COUNT 个 wheel 文件)"
  log_info "  -> wheel 总大小: $(du -sh "$WHEELS_DIR" 2>/dev/null | cut -f1 || echo 'N/A')"

  # 创建 Python 启动器脚本 (Windows .cmd)
  log_info "创建 Office MCP 启动器..."

  OFFICE_BIN_DIR="$BUNDLE_DIR/bin"

  # Windows 启动器 - 使用 bundle 自带的 Python 或系统 Python
  for tool in wordmcp pptmcp excelmcp; do
    cat > "$OFFICE_BIN_DIR/${tool}.cmd" << CMDEOF
@echo off
setlocal
set "BUNDLE_DIR=%~dp0.."
set "PYTHON=%BUNDLE_DIR%\python\python.exe"
set "MCP_OFFICE=%BUNDLE_DIR%\tools\mcp-office"

if exist "%PYTHON%" (
    set "PATH=%BUNDLE_DIR%\python;%BUNDLE_DIR%\python\Scripts;%PATH%"
    "%PYTHON%" -m ${tool}.server %*
) else (
    python -m ${tool}.server %*
)
endlocal
CMDEOF
  done

  # Unix 启动器
  for tool in wordmcp pptmcp excelmcp; do
    cat > "$OFFICE_BIN_DIR/${tool}.sh" << SHEOF
#!/bin/bash
BUNDLE_DIR="\$(cd "\$(dirname "\$0")/.." && pwd)"
PYTHON="\$BUNDLE_DEPS/runtimes/python/bin/python3"
MCP_OFFICE="\$BUNDLE_TOOLS/mcp-office"

if [ -x "\$PYTHON" ]; then
    export PATH="\$BUNDLE_DEPS/runtimes/python/bin:\$PATH"
    export PYTHONPATH="\$MCP_OFFICE/shared/src:\$MCP_OFFICE/wordmcp/src:\$MCP_OFFICE/pptmcp/src:\$MCP_OFFICE/excelmcp/src:\$PYTHONPATH"
    exec "\$PYTHON" -m ${tool}.server "\$@"
else
    exec python3 -m ${tool}.server "\$@"
fi
SHEOF
    chmod +x "$OFFICE_BIN_DIR/${tool}.sh" 2>/dev/null || true
  done

  log_ok "Office MCP 启动器已创建"
fi

# ---- 5. 创建启动器脚本 ----
log_info "创建 MCP 工具启动器..."

BIN_DIR="$BUNDLE_DIR/bin"

if ! $SKIP_PDF; then
# Windows 启动器 (.cmd)
cat > "$BIN_DIR/pdf-reader.cmd" << 'CMDEOF'
@echo off
setlocal
set "BUNDLE_DIR=%~dp0.."
set "NODEJS=%BUNDLE_DIR%\nodejs\node.exe"
set "TOOL=%BUNDLE_DIR%\deps\npm\node_modules\@sylphx\pdf-reader-mcp\dist\index.js"

if exist "%NODEJS%" (
    "%NODEJS%" "%TOOL%" %*
) else (
    node "%TOOL%" %*
)
endlocal
CMDEOF

cat > "$BIN_DIR/pdf-toolkit.cmd" << 'CMDEOF'
@echo off
setlocal
set "BUNDLE_DIR=%~dp0.."
set "NODEJS=%BUNDLE_DIR%\nodejs\node.exe"
set "TOOL=%BUNDLE_DIR%\tools\pdf-toolkit-mcp\dist\index.js"

if exist "%NODEJS%" (
    "%NODEJS%" "%TOOL%" %*
) else (
    node "%TOOL%" %*
)
endlocal
CMDEOF

# Unix 启动器 (.sh)
cat > "$BIN_DIR/pdf-reader.sh" << 'SHEOF'
#!/bin/bash
BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODEJS="$BUNDLE_DEPS/runtimes/nodejs/bin/node"
TOOL="$BUNDLE_DEPS/npm/node_modules/@sylphx/pdf-reader-mcp/dist/index.js"

if [ -x "$NODEJS" ]; then
    exec "$NODEJS" "$TOOL" "$@"
else
    exec node "$TOOL" "$@"
fi
SHEOF

cat > "$BIN_DIR/pdf-toolkit.sh" << 'SHEOF'
#!/bin/bash
BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODEJS="$BUNDLE_DEPS/runtimes/nodejs/bin/node"
TOOL="$BUNDLE_TOOLS/pdf-toolkit-mcp/dist/index.js"

if [ -x "$NODEJS" ]; then
    exec "$NODEJS" "$TOOL" "$@"
else
    exec node "$TOOL" "$@"
fi
SHEOF

chmod +x "$BIN_DIR/pdf-reader.sh" "$BIN_DIR/pdf-toolkit.sh" 2>/dev/null || true
fi   # end of SKIP_PDF guard for launchers

log_ok "启动器脚本已创建"

# ---- 6. 生成离线 MCP 配置文件 ----
log_info "生成离线 MCP 配置文件..."

CONFIG_DIR="$BUNDLE_DIR/config"
INSTALL_BASE='C:\MCP-Tools'  # 默认 Windows 安装路径，安装时可按需修改

if ! $SKIP_PDF; then
  # Claude Code (仅 PDF)
  cat > "$CONFIG_DIR/claude-code.json" << CFGEOF
{
  "mcpServers": {
    "pdf-reader": {
      "command": "${INSTALL_BASE}\\\\bin\\\\pdf-reader.cmd",
      "description": "高性能 PDF 读取、搜索、内容提取和表格识别"
    },
    "pdf-toolkit": {
      "command": "${INSTALL_BASE}\\\\bin\\\\pdf-toolkit.cmd",
      "description": "全能 PDF 操作工具 — 创建、编辑、合并、拆分、水印、表单、加密等"
    }
  }
}
CFGEOF

  # Claude Desktop
  cat > "$CONFIG_DIR/claude-desktop.json" << CFGEOF
{
  "mcpServers": {
    "pdf-reader": { "command": "${INSTALL_BASE}\\\\bin\\\\pdf-reader.cmd" },
    "pdf-toolkit": { "command": "${INSTALL_BASE}\\\\bin\\\\pdf-toolkit.cmd" }
  }
}
CFGEOF

  # Cline
  cat > "$CONFIG_DIR/cline.json" << CFGEOF
{
  "cline.mcpServers": {
    "pdf-reader": { "command": "${INSTALL_BASE}\\\\bin\\\\pdf-reader.cmd" },
    "pdf-toolkit": { "command": "${INSTALL_BASE}\\\\bin\\\\pdf-toolkit.cmd" }
  }
}
CFGEOF

  # Codex
  cat > "$CONFIG_DIR/codex.json" << CFGEOF
{
  "mcp_servers": {
    "pdf-reader": { "command": "${INSTALL_BASE}\\\\bin\\\\pdf-reader.cmd" },
    "pdf-toolkit": { "command": "${INSTALL_BASE}\\\\bin\\\\pdf-toolkit.cmd" }
  }
}
CFGEOF

  # Unix
  cat > "$CONFIG_DIR/all-unix.json" << CFGEOF
{
  "mcpServers": {
    "pdf-reader": { "command": "/opt/mcp-tools/bin/pdf-reader.sh" },
    "pdf-toolkit": { "command": "/opt/mcp-tools/bin/pdf-toolkit.sh" }
  }
}
CFGEOF
fi

if ! $SKIP_OFFICE; then
  # Office-only 配置
  cat > "$CONFIG_DIR/claude-code-office.json" << CFGEOF
{
  "mcpServers": {
    "word": {
      "command": "${INSTALL_BASE}\\\\bin\\\\wordmcp.cmd",
      "env": { "WORD_ALLOWLIST_ROOTS": "C:\\\\Users\\\\%USERNAME%\\\\Documents", "WORD_ENABLE_WRITE": "true" },
      "description": "Word 文档处理 — 51 个工具覆盖文档创建、模板组装、修订跟踪、结构 QA"
    },
    "ppt": {
      "command": "${INSTALL_BASE}\\\\bin\\\\pptmcp.cmd",
      "env": { "PPT_ALLOWLIST_ROOTS": "C:\\\\Users\\\\%USERNAME%\\\\Documents", "PPT_ENABLE_WRITE": "true" },
      "description": "PowerPoint 演示文稿 — 48 个工具含 Output Contract 框架"
    },
    "excel": {
      "command": "${INSTALL_BASE}\\\\bin\\\\excelmcp.cmd",
      "env": { "EXCEL_ALLOWLIST_ROOTS": "C:\\\\Users\\\\%USERNAME%\\\\Documents", "EXCEL_ENABLE_WRITE": "true" },
      "description": "Excel 电子表格 — 65 个工具覆盖公式、图表、数据透视表"
    }
  }
}
CFGEOF

  # Office Unix
  cat > "$CONFIG_DIR/all-unix-office.json" << CFGEOF
{
  "mcpServers": {
    "word": {
      "command": "/opt/mcp-tools/bin/wordmcp.sh",
      "env": { "WORD_ALLOWLIST_ROOTS": "/home", "WORD_ENABLE_WRITE": "true" }
    },
    "ppt": {
      "command": "/opt/mcp-tools/bin/pptmcp.sh",
      "env": { "PPT_ALLOWLIST_ROOTS": "/home", "PPT_ENABLE_WRITE": "true" }
    },
    "excel": {
      "command": "/opt/mcp-tools/bin/excelmcp.sh",
      "env": { "EXCEL_ALLOWLIST_ROOTS": "/home", "EXCEL_ENABLE_WRITE": "true" }
    }
  }
}
CFGEOF
fi

# 全量配置 (PDF + Office)：仅当两者都打包时生成
if ! $SKIP_PDF && ! $SKIP_OFFICE; then
  cat > "$CONFIG_DIR/claude-code-full.json" << CFGEOF
{
  "mcpServers": {
    "pdf-reader": {
      "command": "${INSTALL_BASE}\\\\bin\\\\pdf-reader.cmd",
      "description": "高性能 PDF 读取、搜索、内容提取和表格识别"
    },
    "pdf-toolkit": {
      "command": "${INSTALL_BASE}\\\\bin\\\\pdf-toolkit.cmd",
      "description": "全能 PDF 操作工具 — 创建、编辑、合并、拆分、水印、表单、加密等"
    },
    "word": {
      "command": "${INSTALL_BASE}\\\\bin\\\\wordmcp.cmd",
      "env": { "WORD_ALLOWLIST_ROOTS": "C:\\\\Users\\\\%USERNAME%\\\\Documents", "WORD_ENABLE_WRITE": "true" },
      "description": "Word 文档处理 — 51 个工具"
    },
    "ppt": {
      "command": "${INSTALL_BASE}\\\\bin\\\\pptmcp.cmd",
      "env": { "PPT_ALLOWLIST_ROOTS": "C:\\\\Users\\\\%USERNAME%\\\\Documents", "PPT_ENABLE_WRITE": "true" },
      "description": "PowerPoint 演示文稿 — 48 个工具"
    },
    "excel": {
      "command": "${INSTALL_BASE}\\\\bin\\\\excelmcp.cmd",
      "env": { "EXCEL_ALLOWLIST_ROOTS": "C:\\\\Users\\\\%USERNAME%\\\\Documents", "EXCEL_ENABLE_WRITE": "true" },
      "description": "Excel 电子表格 — 65 个工具"
    }
  }
}
CFGEOF
fi

log_ok "MCP 配置文件已生成"

# ---- 7. 下载 Node.js 便携版（默认打包，使用缓存） ----
if (! $SKIP_NODEJS); then
  log_info "获取 Node.js v$NODE_VERSION ($PLATFORM)..."

  case "$PLATFORM" in
    win)   NODE_ARCHIVE="node-v${NODE_VERSION}-win-x64.zip" ;;
    linux) NODE_ARCHIVE="node-v${NODE_VERSION}-linux-x64.tar.xz" ;;
    mac)   NODE_ARCHIVE="node-v${NODE_VERSION}-darwin-arm64.tar.gz" ;;
    *)     log_error "不支持的平台: $PLATFORM"; exit 1 ;;
  esac

  NODE_DOWNLOAD_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"

  # 使用统一缓存
  NODE_DOWNLOAD_PATH=$(cache_file "$NODE_ARCHIVE" "$NODE_DOWNLOAD_URL")

  log_info "解压 Node.js（从缓存）..."
  NODE_DIR="$BUNDLE_DIR/nodejs-temp"
  mkdir -p "$NODE_DIR"

  case "$PLATFORM" in
    win)
      unzip -q "$NODE_DOWNLOAD_PATH" -d "$NODE_DIR" 2>&1
      mv "$NODE_DIR"/node-v*/* "$BUNDLE_DEPS/runtimes/nodejs/" 2>/dev/null || \
      mv "$NODE_DIR"/*/* "$BUNDLE_DEPS/runtimes/nodejs/" 2>/dev/null
      ;;
    linux)
      tar -xf "$NODE_DOWNLOAD_PATH" -C "$NODE_DIR"
      mv "$NODE_DIR"/node-v*/* "$BUNDLE_DEPS/runtimes/nodejs/" 2>/dev/null
      ;;
    mac)
      tar -xzf "$NODE_DOWNLOAD_PATH" -C "$NODE_DIR"
      mv "$NODE_DIR"/node-v*/* "$BUNDLE_DEPS/runtimes/nodejs/" 2>/dev/null
      ;;
  esac

  rm -rf "$NODE_DIR"
  log_ok "Node.js v$NODE_VERSION 已打包 ($(du -sh "$BUNDLE_DEPS/runtimes/nodejs" 2>/dev/null | cut -f1 || echo 'N/A'))"
fi

# ---- 7.5 下载 Python 嵌入式版本（可选） ----
if ! $SKIP_PYTHON; then
  log_info "下载 Python v$PYTHON_VERSION 嵌入式版本 ($PLATFORM)..."

  PYTHON_EMBED_DIR="$BUNDLE_DEPS/runtimes/python"
  mkdir -p "$PYTHON_EMBED_DIR"

  case "$PLATFORM" in
    win)
      PYTHON_ARCHIVE="python-${PYTHON_VERSION}-embed-amd64.zip"
      PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_ARCHIVE}"
      ;;
    linux)
      log_warn "Linux 平台不支持 Python 嵌入式打包，跳过"
      if $SKIP_OFFICE; then
        SKIP_PYTHON=true
      fi
      ;;
    mac)
      log_warn "Mac 平台不支持 Python 嵌入式打包，跳过"
      SKIP_PYTHON=true
      ;;
  esac

  if ! $SKIP_PYTHON && [ "$PLATFORM" = "win" ]; then
    # 使用统一缓存
    PYTHON_DOWNLOAD_PATH=$(cache_file "$PYTHON_ARCHIVE" "$PYTHON_URL")

    log_info "解压 Python（从缓存）..."
    unzip -q "$PYTHON_DOWNLOAD_PATH" -d "$PYTHON_EMBED_DIR" 2>&1

    # 嵌入式 Python 需要额外配置 pip
    # 修改 python._pth 文件以启用 pip 和 site-packages
    PTH_FILE="$PYTHON_EMBED_DIR/python._pth"
    if [ -f "$PTH_FILE" ]; then
      # 取消 import site 的注释以启用 site-packages
      sed -i 's/#import site/import site/' "$PTH_FILE" 2>/dev/null || true
      # 添加 Lib/site-packages 路径
      if ! grep -q "Lib/site-packages" "$PTH_FILE" 2>/dev/null; then
        echo "Lib/site-packages" >> "$PTH_FILE"
      fi
    fi

    # 下载并安装 pip 到嵌入式 Python
    log_info "为嵌入式 Python 安装 pip..."
    GET_PIP_URL="https://bootstrap.pypa.io/get-pip.py"
    GET_PIP_PATH="$BUILD_DIR/get-pip.py"

    if [ ! -f "$GET_PIP_PATH" ]; then
      curl -L -o "$GET_PIP_PATH" "$GET_PIP_URL" --silent 2>/dev/null || \
      wget -O "$GET_PIP_PATH" "$GET_PIP_URL" -q 2>/dev/null
    fi

    if [ -f "$GET_PIP_PATH" ]; then
      "$PYTHON_EMBED_DIR/python.exe" "$GET_PIP_PATH" --no-warn-script-location 2>&1 | tail -1
      log_ok "pip 已安装到嵌入式 Python"
    else
      log_warn "无法下载 get-pip.py，嵌入式 Python 将无法使用 pip"
    fi

    log_ok "Python v$PYTHON_VERSION 已打包 ($(du -sh "$PYTHON_EMBED_DIR" 2>/dev/null | cut -f1 || echo 'N/A'))"

    # 如果同时有 Office 工具，预装依赖到嵌入式 Python
    if ! $SKIP_OFFICE && [ -d "$WHEELS_DIR" ]; then
      log_info "将 Office 依赖安装到嵌入式 Python..."
      "$PYTHON_EMBED_DIR/python.exe" -m pip install \
        --no-index --find-links "$WHEELS_DIR" \
        fastmcp python-docx python-pptx openpyxl Pillow \
        2>&1 | while IFS= read -r line; do
        echo "         $line"
      done

      # 安装 mcp-office 本地包
      for pkg_dir in shared wordmcp pptmcp excelmcp; do
        if [ -d "$BUNDLE_TOOLS/mcp-office/$pkg_dir" ]; then
          "$PYTHON_EMBED_DIR/python.exe" -m pip install \
            --no-index --find-links "$WHEELS_DIR" \
            -e "$BUNDLE_TOOLS/mcp-office/$pkg_dir" \
            2>&1 | tail -1 || log_warn "$pkg_dir 安装到嵌入式 Python 失败，将在目标机器上安装"
        fi
      done
      log_ok "Office 依赖已安装到嵌入式 Python"
    fi
  fi
fi

# ---- 8. 复制项目文档和配置 ----
log_info "复制项目文档..."

# 将原始 config 模板也复制一份（作为参考）
mkdir -p "$BUNDLE_DIR/docs"
cp "$PROJECT_DIR/README.md" "$BUNDLE_DIR/docs/" 2>/dev/null || true
cp "$PROJECT_DIR/docs/tools-overview.md" "$BUNDLE_DIR/docs/" 2>/dev/null || true

# ---- 9. 复制安装脚本到 bundle ----
log_info "复制安装脚本..."
cp "$PROJECT_DIR/scripts/install.ps1" "$BUNDLE_DIR/" 2>/dev/null || log_warn "install.ps1 尚不存在，将稍后创建"
cp "$PROJECT_DIR/scripts/install.sh" "$BUNDLE_DIR/" 2>/dev/null || log_warn "install.sh 尚不存在，将稍后创建"

# ---- 10. 创建 bundle README ----
cat > "$BUNDLE_DIR/README.md" << 'BUNDLEREADME'
# MCP 离线安装包

本安装包包含以下 MCP 工具及其所有依赖，可在无网络环境中安装使用。

## 包含的工具

### PDF 文档处理
| 工具 | 运行时 | 用途 |
|------|--------|------|
| pdf-reader-mcp | Node.js | PDF 读取、搜索、表格提取、页面渲染 |
| pdf-toolkit-mcp | Node.js | PDF 创建、编辑、合并拆分、水印、表单、加密等 37 个工具 |
BUNDLEREADME

# 如果包含 Office 工具，追加 Office 工具表格
if ! $SKIP_OFFICE; then
  cat >> "$BUNDLE_DIR/README.md" << 'BUNDLEREADME'
### Office 文档处理
| 工具 | 运行时 | 用途 |
|------|--------|------|
| wordmcp | Python | Word 文档创建、模板组装、修订跟踪、结构 QA（51 个工具） |
| pptmcp | Python | PowerPoint 演示文稿编辑、Output Contract 框架（48 个工具） |
| excelmcp | Python | Excel 电子表格、公式、图表、数据透视表（65 个工具） |
BUNDLEREADME
fi

cat >> "$BUNDLE_DIR/README.md" << 'BUNDLEREADME'

## 安装方法

### Windows
以管理员身份运行 PowerShell，执行：
```powershell
.\install.ps1
```
默认安装到 `C:\MCP-Tools`，可通过 `-TargetPath` 参数自定义。

### Linux / Mac
```bash
sudo bash install.sh
```
默认安装到 `/opt/mcp-tools`。

## 目录结构

```
mcp-tools/
├── bin/                    # 工具启动器
│   ├── pdf-reader.cmd/sh
│   ├── pdf-toolkit.cmd/sh
│   ├── wordmcp.cmd/sh      # (Office)
│   ├── pptmcp.cmd/sh       # (Office)
│   └── excelmcp.cmd/sh     # (Office)
├── packages/
│   └── node_modules/       # 所有 npm 依赖
├── pdf-toolkit-mcp/        # pdf-toolkit-mcp 编译产物
├── mcp-office/             # mcp-office 源码 (Office)
│   ├── wordmcp/
│   ├── pptmcp/
│   ├── excelmcp/
│   └── shared/
├── wheels/                 # Python wheel 包 (Office)
├── nodejs/                 # Node.js 便携版（可选）
├── python/                 # Python 嵌入式版（可选）
├── config/                 # MCP 配置文件
├── install.ps1 / install.sh # 安装脚本
└── README.md
```

## 使用方式

安装后，在 AI 工具的 MCP 配置中添加对应工具的命令路径。

### Claude Code
```bash
claude mcp add pdf-reader -- C:\MCP-Tools\bin\pdf-reader.cmd
claude mcp add pdf-toolkit -- C:\MCP-Tools\bin\pdf-toolkit.cmd
claude mcp add word -- C:\MCP-Tools\bin\wordmcp.cmd
claude mcp add ppt -- C:\MCP-Tools\bin\pptmcp.cmd
claude mcp add excel -- C:\MCP-Tools\bin\excelmcp.cmd
```

### Cline (VSCode)
将 `config/cline.json` 中的配置合并到 VSCode 设置。
BUNDLEREADME

log_ok "bundle README 已创建"

# ---- 11. 打包为 zip ----
log_info "创建压缩包..."

cd "$BUILD_DIR"

# 生成版本文件名
DATE_STAMP=$(date +%Y%m%d)
ARCHIVE_NAME="mcp-offline-${PLATFORM}-${DATE_STAMP}"

if $SKIP_NODEJS; then
  ARCHIVE_NAME="${ARCHIVE_NAME}-no-nodejs"
fi
if $SKIP_PYTHON; then
  ARCHIVE_NAME="${ARCHIVE_NAME}-no-python"
fi
if $SKIP_PDF; then
  ARCHIVE_NAME="${ARCHIVE_NAME}-no-pdf"
fi
if $SKIP_OFFICE; then
  ARCHIVE_NAME="${ARCHIVE_NAME}-no-office"
fi

# 压缩：检测环境并选择合适的压缩方式
# WSL 环境下 powershell.exe 需要 Windows 格式路径
if command -v powershell.exe &> /dev/null; then
  # 检查是否在 WSL 中运行
  if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL 环境：将路径转换为 Windows 格式
    if command -v wslpath &> /dev/null; then
      WIN_BUNDLE_DIR=$(wslpath -w "$BUNDLE_DIR" 2>/dev/null || echo "")
      WIN_BUILD_DIR=$(wslpath -w "$BUILD_DIR" 2>/dev/null || echo "")
    fi
    # 如果 wslpath 不可用，手动转换 /mnt/d/... → D:\...
    if [ -z "$WIN_BUNDLE_DIR" ]; then
      WIN_BUNDLE_DIR=$(echo "$BUNDLE_DIR" | sed 's|^/mnt/\([a-zA-Z]\)/|\1:/|' | tr '/' '\\')
      WIN_BUILD_DIR=$(echo "$BUILD_DIR" | sed 's|^/mnt/\([a-zA-Z]\)/|\1:/|' | tr '/' '\\')
    fi
    log_info "WSL 检测: 使用 Windows 路径压缩"
    powershell.exe -Command "Compress-Archive -Path '$WIN_BUNDLE_DIR' -DestinationPath '$WIN_BUILD_DIR\\${ARCHIVE_NAME}.zip' -CompressionLevel Fastest -Force" 2>&1
    COMPRESS_EXIT=$?
  else
    # 原生 Windows (Git Bash)：路径可能可以直接使用
    powershell.exe -Command "Compress-Archive -Path '$BUNDLE_DIR' -DestinationPath '$BUILD_DIR\\${ARCHIVE_NAME}.zip' -CompressionLevel Fastest -Force" 2>&1
    COMPRESS_EXIT=$?
  fi

  # 如果 PowerShell 压缩失败，回退到 zip/tar
  if [ $COMPRESS_EXIT -ne 0 ] || [ ! -f "$BUILD_DIR/${ARCHIVE_NAME}.zip" ]; then
    log_warn "PowerShell 压缩失败，尝试使用 zip..."
    cd "$BUILD_DIR"
    if command -v zip &> /dev/null; then
      zip -r -1 "${ARCHIVE_NAME}.zip" "mcp-offline-bundle" -q
    else
      log_warn "未找到 zip 命令，使用 tar 打包"
      tar -czf "${ARCHIVE_NAME}.tar.gz" "mcp-offline-bundle"
    fi
  fi
elif command -v zip &> /dev/null; then
  cd "$BUILD_DIR"
  zip -r -1 "${ARCHIVE_NAME}.zip" "mcp-offline-bundle" -q
else
  log_warn "未找到 zip 命令，使用 tar 打包"
  cd "$BUILD_DIR"
  tar -czf "${ARCHIVE_NAME}.tar.gz" "mcp-offline-bundle"
fi

# 确定最终的包大小
if [ -f "$BUILD_DIR/${ARCHIVE_NAME}.zip" ]; then
  BUNDLE_SIZE=$(du -sh "$BUILD_DIR/${ARCHIVE_NAME}.zip" 2>/dev/null | cut -f1)
elif [ -f "$BUILD_DIR/${ARCHIVE_NAME}.tar.gz" ]; then
  BUNDLE_SIZE=$(du -sh "$BUILD_DIR/${ARCHIVE_NAME}.tar.gz" 2>/dev/null | cut -f1)
else
  BUNDLE_SIZE="N/A"
fi

# ---- 12. 完成 ----
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          ✅ 打包完成！                       ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  输出文件:    build/${ARCHIVE_NAME}.zip"
echo "║  包大小:      $BUNDLE_SIZE"
echo "║  含 Node.js:  $( $SKIP_NODEJS && echo '否' || echo '是' )"
echo "║  含 Python:   $( $SKIP_PYTHON && echo '否' || echo '是' )"
echo "║  PDF 工具:    $( $SKIP_PDF && echo '跳过' || echo '打包' )"
echo "║  Office 工具: $( $SKIP_OFFICE && echo '跳过' || echo '打包' )"
echo "╠══════════════════════════════════════════════╣"
echo "║  包内容:                                     ║"
echo "║    - PDF 工具 (pdf-reader + pdf-toolkit)    ║"
if ! $SKIP_OFFICE; then
  echo "║    - Office 工具 (wordmcp/pptmcp/excelmcp)  ║"
  echo "║    - Python wheel 包 ($WHEEL_COUNT 个文件)  ║"
fi
echo "║    - 全部 npm 依赖                           ║"
echo "║    - 启动器脚本 (.cmd / .sh)                 ║"
echo "║    - MCP 配置模板 (Claude/Cline/Codex)      ║"
echo "║    - 安装脚本 (install.ps1 / install.sh)    ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  将 build/${ARCHIVE_NAME}.zip 复制到目标机器，"
echo "  解压后运行安装脚本即可。"
echo ""
