# wordmcp — Word 文档 MCP 工具

基于 [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office) 的 Word 处理 MCP 服务器。

## 来源

- **GitHub:** [dosev-ai/mcp-office/wordmcp](https://github.com/dosev-ai/mcp-office/tree/main/wordmcp)
- **包名:** `mcp-office-word` v0.4.0
- **许可:** MIT
- **依赖:** Python >= 3.11, fastmcp >= 3.2.0, python-docx >= 0.8.11

## 核心特性

- 📝 **51 个 MCP 工具**
- 📄 文档创建（含元数据：标题、作者、日期）
- ✍️ 段落/标题/样式操作
- 📊 表格插入与编辑
- 🖼️ 图片嵌入
- 📑 页眉/页脚管理
- 🔧 节配置（方向、页面大小）
- 🔍 查找与替换
- 🎨 字体格式（粗体、斜体、颜色、大小）
- 📋 修订跟踪（Track Changes）支持 — COM 模式
- 🔍 结构 QA 检查
- 📤 PDF/HTML 导出

## 提供的 MCP 工具（部分）

### 文档操作
| 工具名 | 功能 |
|--------|------|
| `create_document` | 创建新 Word 文档 |
| `open_document` | 打开已有文档 |
| `save_document` | 保存文档 |
| `save_as` | 另存为（含 PDF/HTML 导出） |

### 内容编辑
| 工具名 | 功能 |
|--------|------|
| `add_paragraph` | 添加段落 |
| `add_heading` | 添加标题 |
| `add_table` | 插入表格 |
| `add_image` | 插入图片 |
| `find_and_replace` | 查找替换文本 |
| `format_text` | 格式化文本（字体/颜色/大小） |

### 文档结构
| 工具名 | 功能 |
|--------|------|
| `add_header` | 添加页眉 |
| `add_footer` | 添加页脚 |
| `add_section` | 添加节（分页/方向设置） |
| `add_page_break` | 插入分页符 |

### 修订与审阅
| 工具名 | 功能 |
|--------|------|
| `enable_track_changes` | 启用修订模式 ⚡COM |
| `accept_all_changes` | 接受所有修订 ⚡COM |
| `get_comments` | 获取批注 |

> ⚡COM 标记的功能需要 Windows + Microsoft Word 安装 + pywin32

## 安装

```bash
# 从源码安装
git clone https://github.com/dosev-ai/mcp-office.git
cd mcp-office
python -m venv .venv
.venv\Scripts\activate       # Windows
# source .venv/bin/activate   # Linux/Mac
pip install -e ./wordmcp
```

## 配置 AI 工具

### Claude Code

```json
{
  "mcpServers": {
    "word": {
      "command": "python",
      "args": ["-m", "wordmcp.server"],
      "env": {
        "WORD_ALLOWLIST_ROOTS": "C:\\path\\to\\your\\files",
        "WORD_ENABLE_WRITE": "true"
      }
    }
  }
}
```

### DeepSeek Harness (dsh)

dsh 不读取 `mcpServers` JSON，而是从 `~/.dsh/cordis.patch.yml`（Windows 为 `%USERPROFILE%\.dsh\cordis.patch.yml`）加载 MCP 服务器：这是一个 YAML 加载器补丁层，对 web/headless/sdk/acp 等所有 profile 生效。重启 dsh 后工具以 `mcp__<serverName>__<tool>` 命名，例如 `mcp__word__create_document`。

> 若该文件中只有默认的空根占位符 `[]`，请先删除该行，再插入下面的内容。

```yaml
- insert:
    - id: mcp-word
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: word
        transport: stdio
        command: python
        args:
          - '-m'
          - wordmcp.server
        env:
          WORD_ALLOWLIST_ROOTS: '/home'
          WORD_ENABLE_WRITE: 'true'
        # Word 文档处理 MCP — 51 个工具覆盖文档创建、模板组装、修订跟踪、结构 QA
```

请按需修改 `WORD_ALLOWLIST_ROOTS` 等环境变量。离线安装包中的 `scripts/install.sh` / `scripts/install.ps1` 会自动写入该配置（幂等，不会覆盖已有行），完整模板见 `config/dsh.yml`。

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `WORD_ALLOWLIST_ROOTS` | 允许访问的文件根目录（分号分隔） | — |
| `WORD_ENABLE_WRITE` | 启用写操作 | `false` |

## 安全说明

- 文件模式（python-docx）操作本地 `.docx` 文件，无需 Office
- COM 模式需要 Microsoft Word 安装，但功能更完整
- 通过 `WORD_ALLOWLIST_ROOTS` 限制文件访问范围

## 参考链接

- [GitHub 仓库](https://github.com/dosev-ai/mcp-office)
- [wordmcp README](https://github.com/dosev-ai/mcp-office/tree/main/wordmcp)
- [MCP 官方文档](https://modelcontextprotocol.io)
