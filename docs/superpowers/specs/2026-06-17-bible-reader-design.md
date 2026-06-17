# 圣经阅读器 — 设计文档

**日期:** 2026-06-17
**平台:** iOS (iPhone) 优先,代码保留 macOS/iPad 兼容
**目标:** 自用 / 学习项目(Family Controls 用 Development entitlement,不走 App Store 审核)

---

## 1. 目标与范围

构建一个 iPhone 圣经阅读器,核心差异化功能是**"专注锁定"**:用户设定每日阅读时长,未达标前用 iOS Screen Time 框架屏蔽其他选定 App。

功能全集(分阶段交付):
- 纯阅读 + 书卷/章/节导航
- 书签、高亮、笔记
- 全文搜索
- 多译本(和合本 / KJV / WEB),中英对照
- 阅读计划 + 进度追踪
- 硬锁定(屏蔽其他 App 直到达标)

**非目标(本设计明确排除):**
- 账号系统 / 云同步(数据仅本地)
- 社交、分享、社区功能
- 受版权保护的现代译本(NIV/ESV 等)— 仅用公有领域译本
- App Store 上架合规(隐私表单、distribution entitlement 申请)— 留待后续

---

## 2. 技术架构

| 层 | 选型 | 理由 |
|---|---|---|
| UI | SwiftUI | iPhone 优先,沿用 Xcode 模板 |
| 经文存储 | 打包 SQLite + FTS5,经 **GRDB.swift** 访问 | 经文只读、静态、约 3 万节;按 `(book,chapter,verse)` 取节快;FTS5 支撑全文搜索 |
| 用户数据 | **SwiftData** | 书签/高亮/笔记/计划/进度为可变个人数据;模板已配好 ModelContainer |
| 译本下载 | 额外 SQLite 下载到 App Support 目录 | 内置一个默认译本离线可用,其余可选联网下载 |
| 硬锁定 | FamilyControls + ManagedSettings + DeviceActivity | iOS 唯一能屏蔽其他 App 的官方途径 |

**核心原则:经文(只读)与用户数据(可变)分两套存储**,各用最适合的技术,互不污染。

**依赖决定:** 引入 GRDB.swift(轻量 SQLite 封装,Swift Package)。理由:纯 C API 样板代码多;把 3 万节静态经文塞进 SwiftData 会让 store 臃肿且无 FTS5 全文搜索。

### 模块边界

- `BibleStore`(经文访问层)— 输入 `(translation, book, chapter)`,输出经节数组;封装 GRDB,消费方不感知 SQL。
- `SearchService` — 输入查询词,输出命中经节引用列表;封装 FTS5。
- `UserDataStore` — SwiftData 封装,管理书签/高亮/笔记/计划/进度。
- `ReadingTimer` — 阅读计时,仅在阅读页前台时累加。
- `LockController` — 封装 FamilyControls/ManagedSettings,对外只暴露 `applyShield()` / `removeShield()` / `isAuthorized`。
- `ReferenceModel` — 全局通用的经节引用值类型 `(book, chapter, verse)`,各模块共享。

---

## 3. 数据模型

### 经文(SQLite,只读,打包)

```sql
books(id INTEGER PK, name_zh TEXT, name_en TEXT, testament TEXT, chapter_count INTEGER, sort_order INTEGER)
verses(translation_id TEXT, book INTEGER, chapter INTEGER, verse INTEGER, text TEXT,
       PRIMARY KEY(translation_id, book, chapter, verse))
verses_fts USING fts5(text, content='verses')   -- 全文搜索虚拟表
```

- `book` 用数字编号(1=创世记 … 66=启示录),稳定且跨译本一致。
- 多译本共用一套表,以 `translation_id` 区分。

### 用户数据(SwiftData @Model)

- `Bookmark { ref: Reference, createdAt: Date }`
- `Highlight { startRef, endRef, colorHex: String, createdAt }`
- `Note { startRef, endRef, body: String, createdAt, updatedAt }`
- `ReadingPlan { name, dailyTargetMinutes: Int, startDate, shieldedAppsToken: Data? }`
- `ReadingSession { date, actualMinutes: Double, isComplete: Bool }`  ← 驱动锁定
- `LastReadPosition { book, chapter, translationId }`  ← 续读

`Reference` 以可编码值类型(book/chapter/verse)嵌入存储。

> 注:Xcode 模板自带的 `Item.swift` 仅为占位,实现阶段删除。

---

## 4. 分阶段交付计划

每阶段结束都应能编译运行、可演示。

### 阶段 0 — 数据准备
- 获取一份**公有领域和合本(CUV)**文本(脚本下载/转换;若无现成源,计划里含"寻找数据源"步骤)。
- 写一个一次性脚本(Python/Swift,仓库外或 `tools/`)生成 `bible.sqlite`:建表、导入经节、构建 FTS5 索引、填充 `books` 元数据。
- 产物 `bible.sqlite` 放入 App bundle。
- 验收:用命令行查询能按 `(book,chapter,verse)` 取节、FTS5 能搜索。

### 阶段 1 — 纯阅读 MVP(第一个能用的版本)
- 集成 GRDB,实现 `BibleStore`。
- 三级导航:书卷列表 → 章列表 → 阅读视图。
- 阅读视图:章内逐节渲染、节号、流畅滚动。
- 设置:字体大小、深色/浅色模式。
- 续读:记录并恢复 `LastReadPosition`。
- 删除模板的 `Item.swift` / 占位 UI。

### 阶段 2 — 个人标注
- 长按/选择经节 → 加书签、高亮(选色)、写笔记。
- 阅读视图渲染高亮背景、书签/笔记标记。
- 一个"我的标注"列表页,可跳回经节。

### 阶段 3 — 全文搜索
- `SearchService` 基于 FTS5。
- 搜索页:输入词 → 命中经节列表(带引用+片段)→ 点击跳转。

### 阶段 4 — 多译本
- 译本切换器。
- 中英对照(并排/上下,按经节 `(book,chapter,verse)` 对齐)。
- 联网下载额外译本 SQLite 到 App Support;下载管理(已装/可下载)。

### 阶段 5 — 阅读计划 + 硬锁定(技术最难,最后做)
- 阅读计划设定(每日目标分钟)。
- `ReadingTimer`:仅在阅读页前台累加,记入当日 `ReadingSession`。
- 进度:连续天数、今日是否达标。
- 硬锁定子系统(见第 5 节)。

---

## 5. 硬锁定子系统(阶段 5)

**框架:** FamilyControls(授权)+ ManagedSettings(加盾)+ DeviceActivity(可选调度)。

**机制:**
1. 首次启用请求 `AuthorizationCenter` 授权(individual 模式)。
2. 用 `FamilyActivityPicker` 让用户选要屏蔽的 App,保存为不透明 token(`ReadingPlan.shieldedAppsToken`)。
3. 当日 `ReadingSession` 未达标 → `ManagedSettingsStore` 给选定 App 加盾(`shield.applications`)。盾牌持久化,跨 App 重启有效。
4. `ReadingTimer` 累计达标 → 标记 `isComplete = true` → 移除盾。
5. 跨午夜重置:新的一天生成新 `ReadingSession`,重新加盾。

**工程注意:**
- 需 **Family Controls (Development)** capability(Signing & Capabilities 中添加)。
- **必须真机测试**,模拟器不支持 Screen Time API。
- 盾牌 UI 文案可选用 Shield Configuration App Extension 自定义(MVP 可用系统默认)。
- 计时只在前台累加:用 `scenePhase` + 阅读视图 `onAppear/onDisappear` 控制累加开关,防止后台或离开阅读页时刷时长。

**风险:** Family Controls API 受限较多、调试体验差;放在最后阶段,前四阶段不依赖它,即便此功能搁置 App 仍完整可用。

---

## 6. 错误处理与边界

- **经文 DB 缺失/损坏**:启动校验 bundle 内 `bible.sqlite`;缺失则致命错误提示(打包问题)。
- **下载译本失败**:网络错误可重试;已下载文件校验完整性。
- **Family Controls 未授权/被拒**:锁定功能优雅降级为"仅计时提醒",不阻塞阅读。
- **真机权限**:Screen Time 相关功能在模拟器隐藏或提示需真机。
- **空状态**:无标注、无搜索结果、无阅读计划时给出清晰空状态。

---

## 7. 测试策略

- `BibleStore` / `SearchService`:单元测试(用打包 DB 的子集或测试夹具),验证取节、章边界、FTS5 命中。
- `ReadingTimer`:单元测试累加/暂停逻辑(注入时钟)。
- `UserDataStore`:用内存 SwiftData container 测增删改查。
- 锁定子系统:逻辑层(达标判定、跨午夜重置)单元测试;Screen Time 实际屏蔽行为靠真机手动验证。
- UI 关键流程:导航、续读 — 手动 + 适量 UI 测试。

---

## 8. 未决与默认决定

- **GRDB.swift** 作为依赖 — 已采纳(默认)。
- **和合本数据源** — 计划阶段 0 含"获取并转换";若用户已有数据可直接用。
- 经文是否也用 SwiftData — 否,确定用 SQLite(FTS5 + 体积考量)。
