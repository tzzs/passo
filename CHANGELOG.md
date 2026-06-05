# Changelog

## [2.0.0](https://github.com/tzzs/passo/compare/v1.0.0...v2.0.0) (2026-06-05)


### ⚠ BREAKING CHANGES

* **wallet:** WalletView no longer takes a fixed `filter`; it owns the 即将/全部 segment internally. The standalone scan/all tabs are gone.
* **wallet:** WalletView init signature changed from `onAddTapped` to `filter` + `onScanTapped` + `onPhotoTapped`; the scan tab is removed.

### Features

* add App Intents for Siri and Spotlight ([393cdc8](https://github.com/tzzs/passo/commit/393cdc8fb9ceadd4df0ce443b147bea9f894440e))
* add first-launch onboarding and renewal entry UI test ([e755047](https://github.com/tzzs/passo/commit/e7550477dff7aa4e5db58cf737657cdedb7397e6))
* add home-screen up-next ticket widget ([04eea29](https://github.com/tzzs/passo/commit/04eea29ad7f5eb9687c93cd9c83879d12c65d16f))
* add iCloud sync, localization scaffolding, and ticket renewal ([32f6b33](https://github.com/tzzs/passo/commit/32f6b332dce2cc6a887c0248dc42369c3899830e))
* add Live Activity countdown for upcoming tickets ([1a7c7dc](https://github.com/tzzs/passo/commit/1a7c7dcdde6daa6ef29652b58a0a2a4b7f208008))
* add watchOS companion app with on-wrist barcode ([2d312f3](https://github.com/tzzs/passo/commit/2d312f34560e5bf2a93e20fcb7b147384fbd4094))
* Apple Watch 伴侣 App——腕上亮码 ([811b9fe](https://github.com/tzzs/passo/commit/811b9fe86db9e6002e1d25323ee898cd385fd6ef))
* complete client-side P0–P3 backlog (batches 1–3) ([286628a](https://github.com/tzzs/passo/commit/286628a01b45b5889b354564920b23dcda85870a))
* iCloud 同步、本地化、过期票据续期 + 首次引导 ([f743339](https://github.com/tzzs/passo/commit/f743339426c15afd4c8aa8b6eb2abf0dff6184ad))
* implement all 6 UX improvements + B2 second-card tap ([6d090ec](https://github.com/tzzs/passo/commit/6d090ec15d5b622ce37d0616760aa5c7469e8e41))
* implement free-tier gate, location permission, screenshot import, and Share Extension ([8e0c607](https://github.com/tzzs/passo/commit/8e0c607653055e88fbfd9934f60d2248be355a5e))
* **model:** add isArchived + ticket/card classification helpers ([971e0aa](https://github.com/tzzs/passo/commit/971e0aaa5b13c823aa1b4c878571a2134dd2a538))
* optimization pass — 8 items across UX, scanning, and monetization ([7ff9067](https://github.com/tzzs/passo/commit/7ff906770270ff9749bca337146d3006bfd2db4e))
* **passkit:** implement PassKit signing pipeline (M3) ([e84343b](https://github.com/tzzs/passo/commit/e84343be8966fc7588cc6ce6d457eaf8cba5ee7b))
* prioritise in-progress tickets in widget up-next selection ([a86591d](https://github.com/tzzs/passo/commit/a86591d5645e7b53d51f950db2833aabd036b7ff))
* **reminder,map,icloud:** implement M4 smart reminders, M5 map snapshot, M8 iCloud sync ([a405e47](https://github.com/tzzs/passo/commit/a405e477965fcab27d5251983cf6d0072e3eac0b))
* **scan:** add album import entry to scanner ([aff00c5](https://github.com/tzzs/passo/commit/aff00c593cf905b579993cc08f0b71116f86a7f5))
* **scan:** implement AVFoundation camera + Vision barcode + Core Image rendering ([103d261](https://github.com/tzzs/passo/commit/103d26134406dba8952b4547502f3c8fb6a43150))
* **settings:** visualize monthly import quota on membership card ([0b9dba2](https://github.com/tzzs/passo/commit/0b9dba2134f20236ec5a33870e45ce1a2e80df3c))
* **wallet:** dual-tab home, in-place import menu, richer timeline ([fb6f081](https://github.com/tzzs/passo/commit/fb6f081dbe3f779cc5f9ef93eedec6f93b6f3866))
* **wallet:** per-type ticket card layouts matching wireframe designs ([88d11ea](https://github.com/tzzs/passo/commit/88d11eab54cf3079821c5522bb748ea3d695a19c))
* **wallet:** redesign 卡包 as Apple Wallet stacked cards ([13485a7](https://github.com/tzzs/passo/commit/13485a765d2f92859920a17118465a257fe84be8))
* **wallet:** split tickets vs cards into 票据/卡包 tabs + unified archive ([45cf2be](https://github.com/tzzs/passo/commit/45cf2be530ca7608fabfc9ce765fd6fa0cc14302))
* **wallet:** swipe-to-archive + photo import (M6) ([ec5e5c1](https://github.com/tzzs/passo/commit/ec5e5c1c3da44d48f326a23e4898613e4af73e20))
* 主屏小组件——即将使用的票 ([f8b3289](https://github.com/tzzs/passo/commit/f8b3289f74ae514c32906ffe69c457b0e4faaff0))
* 即将开始的票据锁屏倒计时 Live Activity ([9c84dc8](https://github.com/tzzs/passo/commit/9c84dc8da234fa36f619389daa4e8bacfd6ae52c))
* 完成客户端 P0–P3 待办（批次 1–3） ([de2cfa4](https://github.com/tzzs/passo/commit/de2cfa43ea52c36314199a84a83d503ca45e15df))
* 接入 App Intents，支持 Siri 与聚焦搜索 ([fa7699b](https://github.com/tzzs/passo/commit/fa7699b73123b6bfbbd7826b0c0fd53d0fda0247))
* 细化主屏 Widget 选票策略(正在进行优先)+ App Group 回退修复 ([940e140](https://github.com/tzzs/passo/commit/940e1407bd3fe08170551c69c95336e75b1d6636))
* 设置页会员额度可视化 + 卡包 Apple Wallet 层叠样式 ([fd5ae7c](https://github.com/tzzs/passo/commit/fd5ae7c3c11d764a5e5e866650a467dc37386657))


### Bug Fixes

* 4 correctness bugs — nav destination, barcode render, isUsed snapshot, opacity compounding ([bd6d1d3](https://github.com/tzzs/passo/commit/bd6d1d31008eb11439f4d8dbfa24da5e9d453a3e))
* address 6 UX and code-quality issues from audit ([3fce16d](https://github.com/tzzs/passo/commit/3fce16d411d9f934b813b73b9add9a0fb94c47a4))
* avoid sending non-Sendable [String: Any] across actor in Watch receiver ([12112a3](https://github.com/tzzs/passo/commit/12112a35b02dbf12e25623342a607298792e3188))
* detail push transition, deprecated nav API, 3D flip grey, HIG hit targets ([2b5433b](https://github.com/tzzs/passo/commit/2b5433b85ac300e62cd2e4f4b5899bba62e13fff))
* **detail:** improve map target handling ([ba57c45](https://github.com/tzzs/passo/commit/ba57c45ec2313e9df966fea2330dba34bbaacb7b))
* **detail:** resolve PR 8 merge conflicts ([8493d10](https://github.com/tzzs/passo/commit/8493d1053aa690a84f254fda3f62d508f87c6a72))
* **detail:** stabilize expiry editor and edit layout ([420b434](https://github.com/tzzs/passo/commit/420b434b660d0081bbc702b5691fa66ee72ebd62))
* **detail:** stabilize expiry editor and edit layout ([81fa970](https://github.com/tzzs/passo/commit/81fa970b037df0b657072c1a718d45c2839a2d9c))
* **detail:** stabilize expiry editor state ([4feb648](https://github.com/tzzs/passo/commit/4feb648a3eef8a15898a18de8accdd6f49f6ca22))
* **detail:** stop async map snapshot from eating the info-card margins ([dabc81e](https://github.com/tzzs/passo/commit/dabc81e22b7691ab299c2a2e8554b56216bbe4ce))
* **launch:** resolve simulator crash and 4 compile errors ([c926d8e](https://github.com/tzzs/passo/commit/c926d8e80b615b3f29e65d03c1a5592778b4b1be))
* make Watch receiver payloadKey nonisolated ([63f4fe0](https://github.com/tzzs/passo/commit/63f4fe0b57e36a45d7b3faee29053aa6b00d4389))
* make WatchSyncService Sendable-safe under Swift 6 ([afbbb08](https://github.com/tzzs/passo/commit/afbbb08169a34084b80c6a278a1c1695910c4a0e))
* **model:** fall back to local store when App Group container is unavailable ([3b2bcaf](https://github.com/tzzs/passo/commit/3b2bcaf6ac5df94090dd1ece9b9ec0390294ca99))
* **parser,gate:** B1 year rollover for MM-dd dates, B3 monthly import limit ([c1ed004](https://github.com/tzzs/passo/commit/c1ed0049ab4f43df5466242a4bb85155adfb7f51))
* render Watch barcodes on iPhone (watchOS has no CoreImage) ([cbf6c9f](https://github.com/tzzs/passo/commit/cbf6c9fedb918e4a5947aa355fade05bcaa8058c))
* resolve iOS CI build failures ([c013320](https://github.com/tzzs/passo/commit/c0133201d0adb9833a814cf778fc4b27f1039844))
* **scan:** improve image barcode recognition ([39190dd](https://github.com/tzzs/passo/commit/39190ddcb50bc4f7d2d4e9f63d92705b2490439a))
* **scan:** improve image barcode recognition ([4a1fb2d](https://github.com/tzzs/passo/commit/4a1fb2dbf82d149c28b5d88d69862cd50f53f888))
* **scan:** resolve PR merge conflicts ([e16ef4c](https://github.com/tzzs/passo/commit/e16ef4cf7b6b3073a536972db5da397949e27718))
* set sourceApp on all import paths, add unmark-used action, sort used tickets to bottom ([f7dd8ae](https://github.com/tzzs/passo/commit/f7dd8aea3388814b6d90c942ae9f4c39f72fe6d2))
* **ui:** increase GlassPillButton tap target from 40pt to 44pt ([e6e522f](https://github.com/tzzs/passo/commit/e6e522f676637c756ed02443fbe2d18863fbacc7))
* **wallet:** constrain stacked card tap target to the card face ([a6f8b0b](https://github.com/tzzs/passo/commit/a6f8b0b95bf32a02a33f47fa044d1c07d48b38b0))
* **wallet:** countdown days, dual-tab action bar, drop mismatched entry tile ([e12c081](https://github.com/tzzs/passo/commit/e12c0813277f65b7ba4d2740bc72c1052dae081d))
