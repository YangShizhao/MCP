# pptmcp — PowerPoint 演示文稿 MCP 工具

基于 [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office) 的 PowerPoint 处理 MCP 服务器。

## 来源

- **GitHub:** [dosev-ai/mcp-office/pptmcp](https://github.com/dosev-ai/mcp-office/tree/main/pptmcp)
- **包名:** `mcp-office-powerpoint` v0.5.0
- **许可:** MIT
- **依赖:** Python >= 3.11, fastmcp >= 3.2.0, python-pptx >= 0.6.23, Pillow >= 10.0, mcpshared

## 核心特性

- 📊 **48 个 MCP 工具**
- 🎚️ 幻灯片 CRUD（创建、读取、更新、删除）
- 🔷 形状与文本编辑
- 📐 **Output Contract 框架** — 机器可验证的幻灯片规范
- 📋 证据包（Evidence Bundles）
- 📊 表格编辑
- 🖼️ 图片插入
- ✨ 动画（含点击展示）
- 🎤 演讲者备注
- 🔄 幻灯片排序
- 📤 PDF/PNG 导出（COM 模式）、HTML 导出
- 🖥️ 幻灯片放映控制

## 提供的 MCP 工具（部分）

### 演示文稿操作
| 工具名 | 功能 |
|--------|------|
| `create_presentation` | 创建新演示文稿 |
| `open_presentation` | 打开已有演示文稿 |
| `save_presentation` | 保存演示文稿 |
| `export_to_pdf` | 导出为 PDF ⚡COM |

### 幻灯片操作
| 工具名 | 功能 |
|--------|------|
| `add_slide` | 添加幻灯片 |
| `delete_slide` | 删除幻灯片 |
| `duplicate_slide` | 复制幻灯片 |
| `reorder_slides` | 重新排序幻灯片 |

### 内容编辑
| 工具名 | 功能 |
|--------|------|
| `add_text_box` | 添加文本框 |
| `add_table` | 添加表格 |
| `add_image` | 添加图片 |
| `add_shape` | 添加形状 |
| `edit_text` | 编辑文本内容 |

### 高级功能
| 工具名 | 功能 |
|--------|------|
| `add_animation` | 添加动画效果 |
| `set_speaker_notes` | 设置演讲者备注 |
| `apply_output_contract` | 应用 Output Contract 规范 |
| `add_slide_transition` | 添加幻灯片切换效果 |

> ⚡COM 标记的功能需要 Windows + Microsoft PowerPoint 安装 + pywin32

## Output Contract 框架

pptmcp 独有的 **Output Contract** 框架允许 AI 生成机器可验证的幻灯片规范：
- 结构与内容分离
- 自动验证幻灯片是否符合规范
- 适合批量生成标准化的演示文稿

## 安装

```bash
# 从源码安装（需要先安装 shared 包）
git clone https://github.com/dosev-ai/mcp-office.git
cd mcp-office
python -m venv .venv
.venv\Scripts\activate

# pptmcp 依赖 shared 包
pip install -e ./shared
pip install -e ./pptmcp
```

## 配置 AI 工具

### Claude Code

```json
{
  "mcpServers": {
    "ppt": {
      "command": "python",
      "args": ["-m", "pptmcp.server"],
      "env": {
        "PPT_ALLOWLIST_ROOTS": "C:\\path\\to\\your\\files",
        "PPT_ENABLE_WRITE": "true"
      }
    }
  }
}
```

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PPT_ALLOWLIST_ROOTS` | 允许访问的文件根目录（分号分隔） | — |
| `PPT_ENABLE_WRITE` | 启用写操作 | `false` |

## 参考链接

- [GitHub 仓库](https://github.com/dosev-ai/mcp-office)
- [pptmcp README](https://github.com/dosev-ai/mcp-office/tree/main/pptmcp)
- [MCP 官方文档](https://modelcontextprotocol.io)
