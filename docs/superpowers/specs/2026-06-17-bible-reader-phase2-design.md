# 圣经阅读器 Phase 2 — 个人标注 设计文档

**日期:** 2026-06-17
**阶段:** Phase 2(承接 Phase 0+1 已交付的离线阅读 MVP)
**范围:** 书签、整节高亮、笔记,以及"我的标注"汇总页。

---

## 1. 目标与范围

在现有阅读器上增加**个人标注**能力,数据仅本地(SwiftData),与只读经文存储(SQLite/GRDB)分离。

**包含:**
- 书签:标记单节,便于快速回访。
- 高亮:为整节着色(固定 4 色调色板),支持一次选中多节批量上色。
- 笔记:为单节附加文本笔记。
- "我的标注"汇总页:分段列出书签 / 高亮 / 笔记,点击跳回经文。

**非目标(本阶段明确排除):**
- 子句 / 字符级选择(只做整节粒度)。
- 跨章选择。
- 标注的搜索 / 导出 / 同步(后续阶段或不做)。
- 高亮范围行(range row)存储 —— 改为每节一行(见 §3)。

---

## 2. 交互设计

**触发方式:点节选中 + 底部工具栏。**

1. 在 `ReadingView` 中点击某节 → 该节进入选中态(显示选中边框/底色)。
2. 可继续点击其他节进行多选(用于批量高亮 / 批量加书签)。再次点击已选节取消该节。
3. 有选中节时,底部浮出工具栏,含动作:
   - **书签** — 对选中节 toggle 书签。
   - **高亮** — 展开 4 色调色板;选色后对选中节着该色;若选中节已是该色则移除(toggle)。
   - **笔记** — 仅在单节选中时可用;打开编辑 sheet 写 / 改笔记。
   - **取消** — 清空选中态。
4. 操作完成后清空选中态(笔记保存或取消 sheet 后亦然)。

**已标注的视觉反馈(渲染):**
- 高亮节:整节文字背景着对应颜色。
- 书签节:行首显示小书签图标。
- 笔记节:行尾显示小笔记图标,点击可查看 / 编辑该节笔记。

**调色板:** 固定 4 色 —— 黄、绿、蓝、粉。存储为 hex 字符串(如 `#FFE08A`),便于未来增减颜色而不改 schema。

---

## 3. 数据模型(SwiftData @Model)

三个模型均嵌入既有的 `Reference` 值类型(`Codable`,`book/chapter/verse`)。

```swift
@Model final class Bookmark {
    var ref: Reference
    var createdAt: Date
}

@Model final class Highlight {
    var ref: Reference        // 每节一行
    var colorHex: String
    var createdAt: Date
}

@Model final class Note {
    var ref: Reference        // 单节
    var body: String
    var createdAt: Date
    var updatedAt: Date
}
```

**关键决定 —— 高亮每节一行(而非 startRef/endRef 范围行):**
- 整节粒度下,渲染逐节进行;每节一行让"本节是否高亮、什么颜色"成为直接字典查找,无需区间判定。
- 单节改色 / 取消高亮变为单行更新 / 删除,简单可靠。
- 选中多节上色 = 批量 upsert 多行;取消 = 批量删除。
- 代价:同一片连续高亮以多行存储,体量略大,但每节经文仅一行、可忽略。

**辅助方法(各模型 extension,便于单测):**
- `Bookmark.toggle(in:ref:)` — 存在则删,不存在则建。
- `Highlight.setColor(in:ref:colorHex:)` / `Highlight.remove(in:ref:)`,以及"按 (book,chapter) 取本章全部高亮"的查询。
- `Note.upsert(in:ref:body:)`(空 body 视为删除)/ `Note.fetch(in:ref:)`。
- 章级批量查询:`fetchForChapter(in:book:chapter:)` 返回 `[verse: Model]` 字典,供渲染一次性加载。

所有模型加入 `bible_readerApp.swift` 的 `Schema([...])`。

---

## 4. 渲染数据流(ReadingView)

1. 进入章节(`task(id: chapter)`)时,除经文外,额外用 `modelContext` 查询本章的:
   - `[verse: Highlight]`、`Set<verse>`(书签)、`[verse: Note]` 三个查询,各按 `book/chapter` 过滤。
2. 渲染每节时按 verse number 直查上述字典,决定背景色 / 书签图标 / 笔记图标。
3. 标注变更后(toggle / 上色 / 存笔记)刷新这些字典,使视图即时更新。

> 经文读取仍走 `BibleStore`(GRDB,只读);标注读写走 SwiftData `modelContext`。两套存储互不污染,符合总设计 §2 原则。

---

## 5. 根导航调整

当前根为 `NavigationStack`(书卷列表)。本阶段改为 **`TabView`**:

- **Tab 1「阅读」** — 现有 `NavigationStack`(书卷 → 章 → 阅读),保留续读与设置入口。
- **Tab 2「我的标注」** — 新汇总页(自带 `NavigationStack`)。

**"我的标注"页:**
- 分段(Section):书签 / 高亮 / 笔记。
- 每条显示经节引用(如「约翰福音 3:16」,书名经 `BibleStore` 书号→中文名映射)+ 摘要(高亮显示首段经文或色块;笔记显示 body 摘要)。
- 点击任意条目 → 跳到 Tab 1 并 push 到对应章的 `ReadingView`(跨 tab 跳转:用共享的选中 tab + 阅读栈 path 状态)。
- 空状态:无任何标注时显示 `ContentUnavailableView` 提示。

> 跨 tab 跳转的状态(当前 tab、阅读栈 path)上提到 `ContentView`,以便"我的标注"点击能切回阅读 tab 并定位章节。

---

## 6. 错误处理与边界

- 标注写入失败:`modelContext.save()` 失败时静默降级(沿用 `LastReadPosition` 的 `try?` 策略),不阻塞阅读。
- 书名查找失败(理论上不会):汇总页回退显示「书卷N」+ 章节号。
- 空状态:选中态无操作可取消;汇总页各分段及整体均有空状态。
- 笔记空 body:保存时视为删除该笔记,避免空笔记残留。

---

## 7. 测试策略

- **模型逻辑(单元测试,内存 SwiftData 容器,沿用 `LastReadPositionTests` 模式):**
  - `Bookmark.toggle` 建/删往返。
  - `Highlight` 上色、改色、移除、章级字典查询。
  - `Note.upsert` 新建/更新/空 body 删除、`fetch` 命中。
- **渲染与交互:** 手动冒烟(选中、工具栏、调色、笔记 sheet、跨 tab 跳转、深浅色下高亮可读性)。

---

## 8. 已决定的默认

- 整节粒度(非子句级)—— 已采纳。
- 点节选中 + 底部工具栏(支持多节连选)—— 已采纳。
- 高亮每节一行存储 —— 已采纳。
- 根导航改 `TabView`(阅读 / 我的标注)—— 已采纳。
- 4 色固定调色板,hex 存储 —— 已采纳。
