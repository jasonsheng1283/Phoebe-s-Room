# 项目文档索引

本目录是 **Phoebe's Room** 的文档中枢。收到新任务时，先按「上下文加载」顺序阅读关键文件，再按需求工作流推进。

## 目录结构

```
docs/
├── README.md                 # 本索引
├── BACKGROUND.md             # 产品定位与背景
├── GLOSSARY.md               # 术语表
├── WORKFLOW.md               # 需求处理工作流与禁止行为
├── features.md               # 功能点列表（含状态）
├── CHANGELOG.md              # 变更日志
├── PITFALLS.md               # 踩坑与常见错误
├── discussions/              # 讨论存档（按日期）
│   └── YYYYMMDD_*.md
├── plan/                     # 实现计划（大改动/新功能/重构）
│   └── YYYYMMDD_plan.md
└── prd/
    ├── template.md           # PRD 模板
    └── prd.md                # 当前 PRD 入口与版本索引
```

## 上下文加载（必读）

收到新任务时，先读取：

1. `docs/BACKGROUND.md` — 理解产品定位
2. `docs/GLOSSARY.md` — 对齐术语
3. `docs/WORKFLOW.md` — 遵守工作流与禁止行为
4. `docs/features.md` — 了解已有/进行中功能

## Cursor 规则

开发与协作规范同步维护在：

- `.cursor/rules/rule.mdc`
