# Office 文档处理 MCP 工具

本目录包含基于 [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office) 的 MCP 工具套件，覆盖 Word、PowerPoint、Excel 三大 Office 文档类型。

## 来源

- **GitHub:** [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office)
- **许可:** MIT
- **平台:** Windows 10/11（COM 功能需要 Microsoft Office 安装；文件操作可跨平台）
- **Python:** >= 3.11

## 工具列表

### [wordmcp](wordmcp/) — 📝 Word 文档处理
51 个工具，覆盖 Word 文档全生命周期：
- 文档创建与模板组装
- 段落/标题/表格/图片操作
- 修订跟踪（Track Changes）
- 结构 QA 检查
- PDF/HTML 导出

### [pptmcp](pptmcp/) — 📊 PowerPoint 演示文稿
48 个工具（含 Output Contract 框架）：
- 幻灯片 CRUD
- 形状/文本/表格编辑
- 动画与演讲者备注
- Output Contract — 机器可验证的幻灯片规范
- PDF/PNG/HTML 导出

### [excelmcp](excelmcp/) — 📈 Excel 电子表格
65 个工具：
- 工作簿管理
- 单元格/区域读写（含公式）
- 图表（柱状图/折线图/饼图/散点图）
- 数据验证、数据透视表
- PDF/HTML/CSV 导出

## 架构

```
AI 工具 (Claude/Cline/Codex)
    │  MCP stdio 协议
    ↓
mcp-office 服务器 (本地 Python 进程)
 ├─ wordmcp   — Word  (python-docx + COM)
 ├─ pptmcp    — PPT   (python-pptx + COM)
 └─ excelmcp  — Excel (openpyxl + COM)
    │  python-docx / python-pptx / openpyxl / COM
    ↓
Microsoft Office (本地安装, COM 功能需要)
```

## 两套操作模式

| 模式 | 依赖 | 功能 | 平台 |
|------|------|------|------|
| **文件模式** | python-docx/pptx/openpyxl | 创建、读取、编辑 .docx/.pptx/.xlsx 文件 | 跨平台 |
| **COM 模式** | pywin32 + MS Office | 样式、PDF 导出、修订跟踪、实时操控 | Windows |

无 Office 安装时，文件模式的基础读写功能完全可用。

## 快速配置

### Claude Code

```bash
claude mcp add word -- python -m wordmcp.server
claude mcp add ppt -- python -m pptmcp.server
claude mcp add excel -- python -m excelmcp.server
```

> **注意：** 需要先在本地安装 mcp-office。详见各工具目录或使用离线安装包。

## 离线安装

推荐使用本项目的 [离线打包脚本](../scripts/pack.sh)：

```bash
bash scripts/pack.sh --with-python  # 包含 Python 便携版
```

打包脚本会自动：
1. 克隆 mcp-office 仓库
2. 下载所有 pip 依赖为 wheel 包
3. 可选打包 Python 嵌入式版本
4. 生成离线安装包
