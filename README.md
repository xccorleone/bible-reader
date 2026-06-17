# 圣经阅读器 (bible-reader)

一个 iPhone 优先的圣经阅读器,核心差异化功能是**「专注锁定」**:设定每日阅读时长,未达标前用 iOS Screen Time 屏蔽其他 App(规划中)。当前已具备完整的阅读、个人标注、全文搜索与多译本能力。

> 自用 / 学习项目。仅使用**公有领域**译本,不走 App Store 审核。数据全部本地,无账号、无云同步。

## 功能

- **纯阅读** — 书卷 → 章 → 经文三级导航,逐节渲染,字号 / 深浅色设置,自动续读上次位置。
- **个人标注** — 长按选择经节加书签、高亮(多色)、写笔记;「我的标注」列表可跳回原经节。
- **全文搜索** — 基于 SQLite FTS5(trigram 分词,支持中文子串);命中经节带引用与片段,点击跳转。
- **多译本** — 译本切换器;**中英对照**(逐节上下排列,按 `(book,chapter,verse)` 对齐);联网下载额外译本(清单驱动,sha256 校验,原子安装)。
- **专注锁定(规划中,阶段 5)** — 阅读计时 + FamilyControls 硬锁定,详见 [设计文档](#路线图)。

## 技术架构

| 层 | 选型 | 说明 |
|---|---|---|
| UI | SwiftUI | iPhone 优先,保留 macOS/iPad 兼容 |
| 经文存储 | 打包 SQLite + FTS5,经 **GRDB.swift**(SPM)访问 | 只读、静态、约 3.1 万节;`(book,chapter,verse)` 取节快,FTS5 支撑搜索 |
| 用户数据 | **SwiftData** | 书签 / 高亮 / 笔记 / 续读位置等可变个人数据 |
| 译本下载 | 额外 SQLite 下载到 App Support | 内置一个默认译本离线可用,其余按需联网下载 |

**核心原则:** 经文(只读)与用户数据(可变)分两套存储,各用最适合的技术。每个译本是独立的只读 SQLite,开成各自的 `BibleStore`(内置打包 / 下载于 `AppSupport/Translations/<id>.sqlite`)。

- **环境:** Xcode 26 / Swift 5,iOS 26.5+。

## 译本

| id | 名称 | 来源 | 许可 | 提供方式 |
|---|---|---|---|---|
| `cuv` | 简体和合本 (CUV) | getbible.net v2 `cus` | 公有领域 | **内置打包**(`bible-reader/bible.sqlite`) |
| `kjv` | 英王钦定本 (KJV, 1611) | getbible.net v2 `kjv` | 公有领域 | GitHub Release 下载 |
| `web` | 世界英文圣经 (WEB) | getbible.net v2 `web` | 公有领域 | GitHub Release 下载 |

下载译本的清单托管在 [`translations/manifest.json`](translations/manifest.json),`.sqlite` 文件作为 GitHub Release(`translations-v1`)资产。App 内「设置 → 译本管理」可下载 / 删除。

> **分节差异:** 现代校勘译本会省略个别经文(如 WEB 路加福音 17:36、使徒行传 8:37 等文本异文)。构建管线保留真实节号(省略节不入库),对照阅读时缺失的副译本经节显示淡色 `—`。

## 项目结构

```
bible-reader/            # SwiftUI app 源码(27 个 .swift)
  BibleStore.swift         经文访问层(GRDB)
  SearchService.swift      FTS5 全文搜索
  TranslationManager.swift 译本注册 / 清单拉取 / 下载 / 校验 / 删除
  TranslationsView.swift   译本管理界面
  ParallelVerses.swift     中英对照逐节对齐
  ReadingView.swift / VerseRow.swift / ...
  bible.sqlite             打包的和合本经文库(唯一入库的 DB)
bible-readerTests/       # 单元测试(Swift Testing)
tools/                   # 数据构建管线(Python),见 tools/README.md
translations/            # 下载译本清单 manifest.json
```

## 构建与运行

需要 Xcode 26+。

```bash
open bible-reader.xcodeproj   # 在 Xcode 中选 bible-reader scheme + iPhone 模拟器运行
```

命令行构建 / 测试:

```bash
xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 测试

- **Swift 单元测试**(`bible-readerTests/`):经文取节、章/分节边界、FTS5 命中、标注增删改查、译本清单解码、**篡改校验和被拒**、对照拼接等。
- **Python 工具测试**(`tools/`):`python3 -m unittest discover`。

## 数据构建管线(tools/)

从 getbible.net 源 JSON 构建每个译本的独立 `.sqlite`,并生成下载清单。详见 [`tools/README.md`](tools/README.md)。简述:

```bash
cd tools
python3 build_bible_db.py source_<id>.json <id>.sqlite <id>   # 建库(books + verses + verses_fts)
python3 build_manifest.py <release-asset-base-url> ../translations/manifest.json
```

构建产物(`tools/*.sqlite`、`raw_*.json`、`source_*.json`)不入库,仅作为 GitHub Release 资产托管。

## 路线图

| 阶段 | 内容 | 状态 |
|---|---|---|
| 0 | 数据准备(打包 CUV + FTS5) | ✅ |
| 1 | 纯阅读 MVP(导航 / 设置 / 续读) | ✅ |
| 2 | 个人标注(书签 / 高亮 / 笔记) | ✅ |
| 3 | 全文搜索(FTS5) | ✅ |
| 4 | 多译本(切换 / 中英对照 / 下载) | ✅ |
| 5 | 阅读计划 + 硬锁定(Screen Time) | 规划中 |

## 许可与说明

- 经文均为**公有领域**译本;本项目不收录受版权保护的现代译本。
- 自用 / 学习性质,未做 App Store 上架合规(隐私表单、distribution entitlement)。
