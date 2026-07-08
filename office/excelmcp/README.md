# excelmcp — Excel 电子表格 MCP 工具

基于 [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office) 的 Excel 处理 MCP 服务器。

## 来源

- **GitHub:** [dosev-ai/mcp-office/excelmcp](https://github.com/dosev-ai/mcp-office/tree/main/excelmcp)
- **包名:** `mcp-office-excel` v0.6.0
- **许可:** MIT
- **依赖:** Python >= 3.11, fastmcp >= 3.2.0, openpyxl >= 3.1.0

## 核心特性

- 📈 **65 个 MCP 工具**
- 📗 工作簿管理（创建、打开、保存）
- 🔢 单元格/区域读写（支持二维区域）
- 🧮 公式与数组公式
- 🎨 单元格/数字格式、边框
- ➕ 插入/删除行和列
- 📏 自动列宽、排序、筛选
- 📊 图表（柱状图、折线图、饼图、面积图、散点图）
- 📑 工作表管理（添加/删除/重命名/激活）
- ✅ 数据验证
- 🔄 数据透视表
- 📤 PDF/HTML/CSV 导出

## 提供的 MCP 工具（部分）

### 工作簿操作
| 工具名 | 功能 |
|--------|------|
| `create_workbook` | 创建新工作簿 |
| `open_workbook` | 打开已有工作簿 |
| `save_workbook` | 保存工作簿 |
| `export_to_csv` | 导出为 CSV |
| `export_to_pdf` | 导出为 PDF ⚡COM |

### 数据读写
| 工具名 | 功能 |
|--------|------|
| `read_range` | 读取单元格区域数据 |
| `write_range` | 写入二维数组到区域 |
| `write_formula` | 写入公式 |
| `read_sheet` | 读取整个工作表数据 |

### 格式化
| 工具名 | 功能 |
|--------|------|
| `format_cells` | 格式化单元格（数字/日期/货币） |
| `set_borders` | 设置边框 |
| `autofit_columns` | 自动调整列宽 |
| `apply_style` | 应用预定义样式 |

### 数据分析
| 工具名 | 功能 |
|--------|------|
| `add_chart` | 添加图表 |
| `sort_range` | 排序区域 |
| `add_filter` | 添加自动筛选 |
| `create_pivot_table` | 创建数据透视表 |
| `add_data_validation` | 添加数据验证规则 |

### 工作表管理
| 工具名 | 功能 |
|--------|------|
| `add_sheet` | 添加工作表 |
| `delete_sheet` | 删除工作表 |
| `rename_sheet` | 重命名工作表 |
| `activate_sheet` | 激活工作表 |

## 安装

```bash
# 从源码安装
git clone https://github.com/dosev-ai/mcp-office.git
cd mcp-office
python -m venv .venv
.venv\Scripts\activate
pip install -e ./excelmcp
```

## 配置 AI 工具

### Claude Code

```json
{
  "mcpServers": {
    "excel": {
      "command": "python",
      "args": ["-m", "excelmcp.server"],
      "env": {
        "EXCEL_ALLOWLIST_ROOTS": "C:\\path\\to\\your\\files",
        "EXCEL_ENABLE_WRITE": "true"
      }
    }
  }
}
```

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `EXCEL_ALLOWLIST_ROOTS` | 允许访问的文件根目录（分号分隔） | — |
| `EXCEL_ENABLE_WRITE` | 启用写操作 | `false` |

## 与其他 mcp-office 工具的区别

- **wordmcp:** 文档处理，51 工具，模板组装 + 修订跟踪
- **pptmcp:** 演示文稿，48 工具，Output Contract 框架
- **excelmcp:** 电子表格，65 工具，公式/图表/数据透视表

三者可同时安装，共享 `fastmcp` 依赖，模式统一。

## 参考链接

- [GitHub 仓库](https://github.com/dosev-ai/mcp-office)
- [excelmcp README](https://github.com/dosev-ai/mcp-office/tree/main/excelmcp)
- [MCP 官方文档](https://modelcontextprotocol.io)
