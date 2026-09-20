# pdf-reader-mcp

生产级 PDF 读取 MCP 服务器 — 适用于 AI 代理的高性能 PDF 内容提取、搜索和分析。

## 来源

- **GitHub:** [SylphxAI/pdf-reader-mcp](https://github.com/SylphxAI/pdf-reader-mcp)
- **npm:** [@sylphx/pdf-reader-mcp](https://www.npmjs.com/package/@sylphx/pdf-reader-mcp)
- **Stars:** ⭐ 226+ | **周下载量:** ~4,400
- **许可:** MIT

## 核心特性

- 🚀 **并行处理** — 5-10 倍速度提升（对比串行处理）
- 📐 **Y 坐标排序** — 保留文档原始布局和阅读顺序
- 🔍 **文本搜索** — 带边界框 (bbox) 证据的精确定位
- 🖼️ **页面渲染** — 将 PDF 页面渲染为图像
- 📊 **表格智能** — 列感知的阅读顺序，表格数据提取
- 🛡️ **容错** — 逐页错误隔离，单页失败不影响整体
- 🎯 **路径支持** — 绝对路径/相对路径，Windows/Unix 通用

## 安装

```bash
# 全局安装
npm install -g @sylphx/pdf-reader-mcp

# 或使用 npx 直接运行（无需安装）
npx @sylphx/pdf-reader-mcp
```

## 提供的 MCP 工具

| 工具名 | 功能 |
|--------|------|
| `pdf_read` | 读取 PDF 全部或指定页面范围的文本内容 |
| `pdf_search` | 在 PDF 中搜索关键词，返回匹配位置和上下文 |
| `pdf_extract_tables` | 提取 PDF 中的表格数据 |
| `pdf_render_page` | 将指定页面渲染为图像 |
| `pdf_get_metadata` | 获取 PDF 元数据（标题、作者、页数等） |
| `pdf_get_outline` | 获取 PDF 文档大纲/目录结构 |
| `pdf_inspect` | 预检 PDF 文件，返回文档结构和属性信息 |
| `pdf_crop_region` | 裁剪并提取页面指定区域的内容 |

## 在不同 AI 工具中配置

### Claude Code

```bash
claude mcp add pdf-reader -- npx @sylphx/pdf-reader-mcp
```

或手动添加到 `.claude/mcp.json`：

```json
{
  "mcpServers": {
    "pdf-reader": {
      "command": "npx",
      "args": ["@sylphx/pdf-reader-mcp"]
    }
  }
}
```

### Cline (VSCode)

在 VSCode 设置中添加：

```json
{
  "cline.mcpServers": {
    "pdf-reader": {
      "command": "npx",
      "args": ["@sylphx/pdf-reader-mcp"]
    }
  }
}
```

### Codex

在 `~/.codex/config.toml` 中添加 MCP 配置段。

### Continue (VSCode)

在 `config.json` 的 `mcpServers` 段中添加相同配置。

### DeepSeek Harness (dsh)

dsh 的 MCP 服务器写在 `$DSH_HOME/cordis.patch.yml`（默认 `~/.dsh/cordis.patch.yml`，
Windows 为 `%USERPROFILE%\.dsh\cordis.patch.yml`）。该文件是 YAML 加载器补丁层，
对**所有** dsh profile（web / headless / sdk / acp）生效；若其中只有默认的空根占位符
`[]`，请先删除该行。重启 dsh 后工具以 `mcp__pdf-reader__<tool>` 的名称出现。

```yaml
- insert:
    - id: mcp-pdf-reader
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: pdf-reader
        transport: stdio
        command: npx
        args:
          - '@sylphx/pdf-reader-mcp'
```

完整模板见 [`config/dsh.yml`](config/dsh.yml)；离线安装包的 `install.sh` / `install.ps1`
会自动写入该配置（并改用打包的 `bin/pdf-reader.cmd` / `bin/pdf-reader.sh` 启动器）。

## 使用示例

### 基本读取

```
请使用 pdf_read 工具读取 /path/to/document.pdf 的前 5 页内容，并总结要点。
```

### 搜索与提取

```
使用 pdf_search 在 /path/to/report.pdf 中搜索 "季度收入"，然后提取包含该关键词的页面内容。
```

### 表格提取

```
使用 pdf_extract_tables 提取 /path/to/financial.pdf 第 3 页的所有表格数据，并转换为 Markdown 格式。
```

## 参考链接

- [GitHub 仓库](https://github.com/SylphxAI/pdf-reader-mcp)
- [npm 包](https://www.npmjs.com/package/@sylphx/pdf-reader-mcp)
- [MCP 官方文档](https://modelcontextprotocol.io)
