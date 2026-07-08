# pdf-toolkit-mcp

功能最全面的 PDF 操作 MCP 服务器 — 37 个工具覆盖 PDF 全生命周期：读取、创建、合并、拆分、水印、表单填充、加密、压缩等。

## 来源

- **GitHub:** [beepboop2025/pdf-toolkit-mcp](https://github.com/beepboop2025/pdf-toolkit-mcp)
- **npm:** ⚠️ 未发布到 npm，需从 GitHub 源码安装
- **许可:** MIT
- **依赖:** pdf-lib, unpdf (Mozilla pdf.js), zod

## 核心特性

- 🔧 **37 个 MCP 工具** — 涵盖 PDF 操作的所有常见需求
- 📄 **读取与搜索** — 文本提取、关键词搜索、元数据获取
- ✏️ **创建与编辑** — 从零创建 PDF、添加/删除页面、旋转、裁剪
- 🔗 **合并与拆分** — 多文件合并、按页拆分、提取指定页面范围
- 🎨 **水印与印章** — 文字水印、图片水印、页眉页脚、自定义印章
- 📝 **表单操作** — 表单字段填写（文本/复选框/下拉/单选）
- 🔒 **安全** — 加密、解密、权限设置
- 🔍 **比较** — PDF 文档差异对比
- 🗜️ **优化** — 压缩、线性化、PDF/A 转换
- 📎 **附件** — 添加/提取/删除 PDF 附件

## 安装

> **注意：** 此工具未发布到 npm，需通过 GitHub 源码安装。

```bash
# 从 GitHub 获取
git clone https://github.com/beepboop2025/pdf-toolkit-mcp.git
cd pdf-toolkit-mcp
npm install
npm run build

# 手动配置 MCP 客户端，指向编译产物
# 命令: node /path/to/pdf-toolkit-mcp/dist/index.js
```

### 离线安装

推荐使用本项目提供的 [离线打包脚本](../../scripts/pack.sh)，自动完成克隆、安装依赖和编译：`bash scripts/pack.sh`

## 提供的 MCP 工具（部分）

### 📖 读取类
| 工具名 | 功能 |
|--------|------|
| `read_pdf` | 读取 PDF 全部或指定页面文本 |
| `search_pdf` | 在 PDF 中搜索关键词 |
| `get_metadata` | 获取 PDF 元数据 |
| `get_info` | 获取 PDF 详细信息（页数、大小、字体等） |
| `extract_images` | 提取 PDF 中的图片 |
| `extract_annotations` | 提取 PDF 批注和注释 |

### ✏️ 编辑类
| 工具名 | 功能 |
|--------|------|
| `merge_pdfs` | 合并多个 PDF 文件 |
| `split_pdf` | 拆分 PDF（按页数或页面范围） |
| `rotate_pages` | 旋转页面 |
| `crop_pages` | 裁剪页面 |
| `delete_pages` | 删除指定页面 |
| `reorder_pages` | 重新排序页面 |
| `add_watermark` | 添加文字或图片水印 |
| `add_stamp` | 添加印章/签名 |
| `fill_form` | 填写 PDF 表单 |
| `redact_text` | 密文处理（遮蔽敏感内容） |

### 🛡️ 安全与优化
| 工具名 | 功能 |
|--------|------|
| `encrypt_pdf` | 加密 PDF（设置密码） |
| `decrypt_pdf` | 解密 PDF |
| `compress_pdf` | 压缩 PDF 文件大小 |
| `optimize_pdf` | 优化 PDF（线性化，适合 Web 查看） |
| `compare_pdfs` | 对比两个 PDF 的差异 |
| `pdf_to_pdfa` | 转换为 PDF/A 归档格式 |

### 📝 创建类
| 工具名 | 功能 |
|--------|------|
| `create_pdf` | 从 HTML/Markdown/文本创建 PDF |
| `create_from_images` | 从图片创建 PDF |
| `add_attachment` | 添加文件附件 |
| `extract_attachment` | 提取文件附件 |

## 在不同 AI 工具中配置

### Claude Code

```bash
claude mcp add pdf-toolkit -- npx @beepboop2025/pdf-toolkit-mcp
```

或手动添加到 `.claude/mcp.json`：

```json
{
  "mcpServers": {
    "pdf-toolkit": {
      "command": "npx",
      "args": ["@beepboop2025/pdf-toolkit-mcp"]
    }
  }
}
```

### Cline (VSCode)

在 VSCode 设置中添加：

```json
{
  "cline.mcpServers": {
    "pdf-toolkit": {
      "command": "npx",
      "args": ["@beepboop2025/pdf-toolkit-mcp"]
    }
  }
}
```

### Codex / Continue

配置格式同上，参考各工具的 MCP 配置文档。

## 使用示例

### 合并 PDF

```
使用 merge_pdfs 将 /path/to/a.pdf 和 /path/to/b.pdf 合并，保存为 /path/to/merged.pdf
```

### 表单填写

```
使用 fill_form 填写 /path/to/tax-form.pdf 中的表单：
- "姓名" 字段填 "张三"
- "日期" 字段填 "2026-07-08"
将填写好的表单保存为 /path/to/filled-form.pdf
```

### 添加水印

```
使用 add_watermark 给 /path/to/document.pdf 所有页面添加 "机密" 水印，保存为 /path/to/watermarked.pdf
```

## 与 pdf-reader-mcp 的配合使用

- **pdf-reader-mcp** 擅长：读取、搜索、表格提取、页面渲染（**读**）
- **pdf-toolkit-mcp** 擅长：创建、编辑、合并/拆分、加密、表单（**写**）

推荐同时配置两个工具，实现完整的 PDF 读写能力。

## 参考链接

- [GitHub 仓库](https://github.com/beepboop2025/pdf-toolkit-mcp)
