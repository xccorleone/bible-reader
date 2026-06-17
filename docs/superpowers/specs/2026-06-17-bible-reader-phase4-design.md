# 圣经阅读器 — 阶段 4 设计:多译本

**日期:** 2026-06-17
**前置:** 阶段 0–3 已合入 `main`(阅读、标注、全文搜索)。
**范围:** 译本切换器 + 中英对照(逐节上下排列)+ 联网下载额外译本(完整子系统)。

---

## 1. 目标与决定

在已有的简体和合本(`cuv`,打包只读)之上,支持:

1. **译本切换器** — 选择主译本,并可叠加一个对照(副)译本。
2. **中英对照** — 逐节上下排列(主译本一行,副译本紧随其下),按 `(book,chapter,verse)` 对齐。
3. **联网下载额外译本** — 完整子系统:清单(manifest)拉取、下载、校验、安装、删除。

**已确定决定:**

| 维度 | 决定 |
|---|---|
| 交付方式 | 构建完整的联网下载子系统(非仅打包第二译本) |
| 托管 | **GitHub Releases**:`.sqlite` 作为 Release 资产;`manifest.json` 提交进仓库,经 `raw.githubusercontent.com` 提供 |
| 初始目录 | **KJV**(英王钦定本)+ **WEB**(World English Bible),均为公有领域 |
| 对照排版 | **逐节上下排列**(适配窄屏 iPhone) |
| 多库策略 | 每个译本一个独立 `DatabaseQueue`(不使用 GRDB ATTACH) |
| 设置持久化 | `ReadingSettings`(`UserDefaults`)新增 `primaryTranslationID` 与可选 `secondaryTranslationID` |

**非目标:** 账号/云同步;增量/差分更新译本;译本内多版本管理;非公有领域译本。

---

## 2. 模块边界(新增 / 改动)

| 单元 | 职责 |
|---|---|
| `TranslationManifest` / `RemoteTranslation`(新) | 从托管 `manifest.json` 解码的 Codable 模型:`id, nameZH, nameEN, abbrev, language, url, bytes, sha256`。 |
| `TranslationManager`(新,`@Observable`) | 译本注册中心。知晓内置 `cuv`(打包只读);跟踪 App Support 中已下载译本;拉取 manifest;下载(进度 + sha256 校验 + 原子安装);删除;按译本 id 提供 `BibleStore`。 |
| `Downloader`(新,protocol) | 对 `URLSession` 下载的薄封装,测试可注入假实现(不触网)。 |
| `BibleStore`(改) | 保持「每译本一个实例」(现状即如此)。内置实例打开 bundle;下载实例打开 `AppSupport/Translations/<id>.sqlite`。书卷元数据**始终**取自内置库(书目跨译本一致)。 |
| `ReadingView` / `VerseRow`(改) | 接收 `primary: BibleStore` 与可选 `secondary: BibleStore?`;设置副译本时逐节上下排列。 |
| `TranslationsView`(新) | 设置中的「译本管理」页:已安装列表(`cuv` 标注且不可删)+ 可下载列表(大小、进度、删除)。 |
| `ReadingSettings`(改) | 新增持久化 `primaryTranslationID`、可选 `secondaryTranslationID`。 |
| `SearchService`(改) | 指向**主译本**的库;主译本切换时随之重建。下载库自带 `verses_fts`。搜索保持单译本(主)。 |

---

## 3. 数据 / 构建(tools/)与清单

- 复用 `build_bible_db.py`(不改),从 getbible 源(`kjv`、`web`)构建独立的 `kjv.sqlite` / `web.sqlite`,各自自包含(`books` + `verses` + `verses_fts`)。
- 新增 `build_manifest.py`:对每个文件计算 sha256 与字节大小,生成 `manifest.json`。
- `.sqlite` 文件 → 上传为 **GitHub Release 资产**;`manifest.json` 提交进仓库,经 `raw.githubusercontent.com` 提供。manifest URL 在 App 中为**单一可配置常量**。
- 在 `tools/README.md` 记录 KJV/WEB 出处与公有领域许可。

`manifest.json` 形态:

```json
{
  "schemaVersion": 1,
  "translations": [
    { "id": "kjv", "nameZH": "英王钦定本", "nameEN": "King James Version",
      "abbrev": "KJV", "language": "en",
      "url": "https://github.com/<owner>/<repo>/releases/download/translations-v1/kjv.sqlite",
      "bytes": 0, "sha256": "<hex>" },
    { "id": "web", "nameZH": "世界英文圣经", "nameEN": "World English Bible",
      "abbrev": "WEB", "language": "en",
      "url": "https://github.com/<owner>/<repo>/releases/download/translations-v1/web.sqlite",
      "bytes": 0, "sha256": "<hex>" }
  ]
}
```

---

## 4. 存储与多库策略

- 每个译本一个独立 `DatabaseQueue`,**不使用 GRDB ATTACH**。内置 `cuv` 只读;下载文件位于 `AppSupport/Translations/<id>.sqlite`。
- **原子安装**:下载 → 临时文件 → 对照 manifest 校验 sha256 → `FileManager` 移入目标位置 → 打开队列。校验不符 ⇒ 丢弃临时文件并报错。
- App Support 目录在启动时确保存在(`Translations/`)。

---

## 5. 阅读体验(切换器 + 对照)

- 阅读视图工具栏新增译本菜单:选择**主译本**,并可切换一个**副译本(对照)**;仅**已安装**译本可选。
- 逐节上下排列:节号 → 主译本行 → 紧随其下的副译本行,按节号对齐。
- 高亮 / 书签 / 笔记仍以 `(book,chapter,verse)` 为键,锚定到**主译本**行。

---

## 6. 下载管理(译本管理页)

- `TranslationsView`:顶部为内置 + 已安装;「可下载」区来自 manifest,显示大小、下载按钮 → 确定性进度 → 安装完成。
- 删除移除文件(`cuv` 除外)。
- 离线 / manifest 拉取失败 ⇒ 行内重试;阅读永不被阻塞(`cuv` 始终可用)。

---

## 7. 错误处理与边界

- **不同译本的分节差异**(真实存在:CUV 与 KJV 的节号可能不一致):按节号对齐;副译本缺该节号时显示淡色 `—`。作为**已知限制**记录,不静默丢弃。
- 选中的主 / 副译本被删除 ⇒ 主译本回退到 `cuv`、副译本清空。
- 无网络 / 校验不符 / 磁盘空间不足 / 打开时库损坏 ⇒ 明确报错并安全清理;绝不破坏已安装集合。
- manifest schema 版本不被支持 ⇒ 提示需要更新 App,不崩溃。

---

## 8. 测试策略

- `TranslationManager`(注入 `Downloader` + 本地 fixture):manifest 解码、成功安装、**篡改校验和被拒**、删除、删除选中译本后的回退逻辑。
- `BibleStore`:对第二个内存译本的取节。
- 对照拼接逻辑:对齐节 + 缺节情形。
- 扩展构建工具测试:用极小的 KJV 形态 fixture 构建。

---

## 9. 已知前置(部署步骤,非阻塞)

GitHub Releases 托管需要一个 **GitHub remote + 已发布的 Release**,当前仓库尚无 remote。整个子系统针对注入的 `Downloader` / fixture 构建并测试,因此这是**部署步骤**而非开发阻塞:真实 manifest URL 与 Release 上传在准备推送时进行,届时提供确切命令。

---

## 10. 验收

- 可在阅读视图切换主译本;切换后经文与搜索均生效。
- 可叠加副译本,逐节上下对照显示;移除副译本恢复单译本。
- 译本管理页可从 manifest 下载 KJV / WEB(带进度与校验),可删除;离线优雅降级。
- 所有新增逻辑有单元测试覆盖;`main` 构建通过。
