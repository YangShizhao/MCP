# PDF 文档处理 MCP 工具

本目录包含 PDF 文档处理相关的 MCP 工具。

## 工具列表

### [pdf-reader-mcp](pdf-reader-mcp/) — 📖 读取与分析
高性能 PDF 读取服务器，专为 AI 代理设计：
- 并行处理，5-10x 速度提升
- 文本提取、搜索、表格识别
- 页面渲染、内容裁剪
- 94%+ 测试覆盖率，生产级稳定性

**安装：** `npm install -g @sylphx/pdf-reader-mcp`

### [pdf-toolkit-mcp](pdf-toolkit-mcp/) — 🔧 编辑与操作
全能 PDF 工具集，37 个工具覆盖全生命周期：
- 创建、合并、拆分、旋转、裁剪
- 水印、印章、表单填充、密文处理
- 加密、解密、压缩、优化
- PDF 对比、附件管理

**安装：** `npm install -g @beepboop2025/pdf-toolkit-mcp`

## 配合使用

两个工具互补，建议同时配置：

```
┌─────────────────────────────────────┐
│           PDF 工作流程               │
├──────────────┬──────────────────────┤
│  读取阶段     │  编辑阶段             │
│              │                      │
│  pdf-reader  │  pdf-toolkit         │
│  ├─ 搜索     │  ├─ 创建新 PDF       │
│  ├─ 提取     │  ├─ 合并拆分         │
│  ├─ 表格     │  ├─ 水印印章         │
│  └─ 渲染     │  ├─ 表单填写         │
│              │  ├─ 加密保护         │
│              │  └─ 压缩优化         │
└──────────────┴──────────────────────┘
```

## 快速配置

将各工具的 `config/` 目录中的配置合并到你的 AI 工具配置文件中。

### Claude Code

```bash
# 一键添加
claude mcp add pdf-reader -- npx @sylphx/pdf-reader-mcp
claude mcp add pdf-toolkit -- npx @beepboop2025/pdf-toolkit-mcp
```

### DeepSeek Harness (dsh)

将 `config/dsh.yml` 中的 `- insert:` 整段追加到 `~/.dsh/cordis.patch.yml`
（Windows：`%USERPROFILE%\.dsh\cordis.patch.yml`，若文件里只有空根占位符 `[]` 请先删除该行）。
该文件是 dsh 的 YAML 加载器补丁层，对所有 profile 生效；重启 dsh 后工具以
`mcp__pdf-reader__<tool>` / `mcp__pdf-toolkit__<tool>` 出现。

```bash
# 离线安装包会自动完成上述配置
bash install.sh          # Linux / Mac
.\install.ps1            # Windows
```

其他 AI 工具（Cline、Codex、Continue、Claude Desktop）的模板见各自 `config/` 目录。
