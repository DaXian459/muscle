# 项目约定

## 每次改动都要提交本地 git

**改完就提交本地仓库，不要留未提交的改动。**

**不要自动推送。** 只有用户明确说「推到 GitHub / 提交到 GitHub」时才 `git push`；
其余情况一律只做本地提交，哪怕远端已经配好、落后多少都不管。

- 一个改动一个提交，不相关的改动不要混在同一个提交里
- 提交信息用中文，写清**做了什么**和**为什么**，不要只写「更新」「fix bug」
- 提交前必须都过：

  ```bash
  flutter analyze   # 无问题
  flutter test      # 全部通过
  ```

- 改动会影响 Android 产物时（数据和界面逻辑、资源、Gradle 配置），再跑一遍
  `flutter build apk --release` 确认能编译
- 提交信息末尾不要加工具署名

### 需要推送时

远端：`https://github.com/DaXian459/muscle.git`（公开）。

本地 git 配置里已为 github.com 设了代理（直连约 12 秒且经常超时）。这条配置只作用于
本仓库、不在版本控制里，换台机器需要重新配。

## 构建配置偏离 Flutter 默认模板的三处

仓库里这三处和 `flutter create` 的默认产物不同，**改动前先看清楚原因**：

| 位置 | 为什么不同 |
| --- | --- |
| `android/settings.gradle.kts`、`android/build.gradle.kts` | 用 `dl.google.com/dl/android/maven2` 代替 `google()`。两者是同一份 Google Maven 仓库，只是 `maven.google.com` 在部分网络下不可达 |
| `android/gradle.properties` 的 `kotlin.incremental=false` | 绕开 Kotlin 2.4.0 增量编译缓存的一个稳定报错（`Could not close incremental caches ... Storage ... is already registered`）。只影响编译速度，不影响产物，网络/工具链正常的机器上可以试着删掉 |
| 没有 `windows/` 平台目录 | 为 Windows 插件建符号链接需要系统开发者模式。要做桌面版，先打开开发者模式再 `flutter create --platforms=windows .` |

## 数据行为：周计划只往前看

- **今天及以后**：改动周计划会自动同步（新增的器械补进来、组数重量跟着更新、
  已完成状态保留、当天临时加练的器械保留）
- **过去的日期**：一律不套用周计划。哪怕那天没有任何记录，也不会凭空出现今天
  才加进计划的器械。要补记必须显式走「按周计划补记」（`AppStore.syncWithPlan`），
  补记之后也不再被计划改动影响

训练日志的价值在于忠实反映当时发生了什么，不能被之后的编辑改写。
动 `AppStore.sessionFor` / `_syncUpcomingSessions` 时务必守住这条，
`test/app_store_test.dart` 里有对应回归测试。
