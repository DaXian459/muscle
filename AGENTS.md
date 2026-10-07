# 项目约定

## 每次改动都要提交并推送

**改完就提交，然后推送到 origin。不要留未提交或未推送的改动。**

远端：`https://github.com/DaXian459/muscle.git`（公开）

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
- 推送用 `git push`。本仓库已单独为 github.com 配好代理
  （`http.https://github.com/.proxy` → `http://127.0.0.1:7897`），
  因为本机直连 GitHub 要 12 秒且经常超时；这条配置只对本仓库生效，没动全局设置

## 先看 README 再动构建配置

有几处是为适配本机环境才这么写的，**不是通用做法**，换环境可能要还原：

| 位置 | 原因 |
| --- | --- |
| `android/settings.gradle.kts`、`android/build.gradle.kts` | 本机 `maven.google.com` 不可达，改用等价的 `dl.google.com` 镜像 |
| `android/gradle.properties` 的 `kotlin.incremental=false` | Kotlin 2.4.0 的增量编译缓存在本机稳定报错 |
| 没有 `windows/` 平台目录 | 为 Windows 插件建符号链接需要开发者模式 |

详见 README「本机的 Android 构建环境」。

## 数据行为：周计划只往前看

- **今天及以后**：改动周计划会自动同步（新增的器械补进来、组数重量跟着更新、
  已完成状态保留、当天临时加练的器械保留）
- **过去的日期**：一律不套用周计划。哪怕那天没有任何记录，也不会凭空出现今天
  才加进计划的器械。要补记必须显式走「按周计划补记」（`AppStore.syncWithPlan`），
  补记之后也不再被计划改动影响

训练日志的价值在于忠实反映当时发生了什么，不能被之后的编辑改写。
动 `AppStore.sessionFor` / `_syncUpcomingSessions` 时务必守住这条，
`test/app_store_test.dart` 里有对应回归测试。
