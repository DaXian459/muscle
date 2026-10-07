# 健身器械记录（muscle）

一个用 Flutter 写的每日健身器械使用记录 App：**按周安排训练计划**，每天照着清单练完一台就勾一台，训练历史自动留存。

支持 Android / iOS / Web（工程目录已生成）。Windows 桌面平台的 `windows/` 目录已按需要移除，可用 `flutter create --platforms=windows .` 重新生成。

## 功能

### 今日训练
- 打开就显示当天要练的器械清单，默认按「今天是星期几」从周计划里带出来。
- 每台器械显示组数 × 次数 × 重量和备注，**练完点一下打勾即标记为已完成**，进度条实时更新。
- 顶部可以前后翻日期：补记昨天的训练、提前看看明天的安排都行；不在今天时会出现「回到今天」。
- 除计划内的器械，还能随时**临时添加**当天用到的器械（会标注来源），或一键「全部完成」。
- 改了周计划会**自动同步到今天及以后**：新增的器械直接出现，改动的组数/重量跟着更新，已经打过的卡不受影响；已经清掉的日期不会被重新填满。
- **过去的日期一律不套用周计划**，只有当时真的记过的才留在那里；要补记某一天，翻到那天点「按周计划补记」。

### 周计划
- 周一到周日分别维护一份器械清单，每天可以有多台器械。
- 添加时能从「常用器械」里一键选名（卧推架、高位下拉、腿举机、划船机……），再填组数、次数、重量、备注。
- 支持**把某一天的安排复制到其他几天**，或整天地清空，用来快速铺开一周的计划。
- 顶部一周概览显示每周动作总数、训练天数、本周已完成数量和累计打卡天数。

### 历史记录
- 累计统计：训练天数、完成器械次数、连续打卡天数。
- 按月份分组的训练卡片，显示每天完成了几台器械和进度条，已完成的器械名以标签列出。
- 可以按「全部 / 已完成 / 未完成」筛选。
- 点进任意一天可以查看详情、补打卡、修正或删除记录。

## 运行

需要 Flutter 3.47 或更高版本（Dart 3.13+）。本机 SDK 安装在 `F:\env\flutter`。

```bash
# 如果 flutter 还没加进 PATH，直接用完整路径
export PATH="/f/env/flutter/bin:$PATH"

cd /f/project/muscle
flutter pub get
flutter run              # 连接设备/模拟器后运行
flutter run -d chrome    # 直接在浏览器里跑
```

打包：

```bash
flutter build apk --release   # Android，产物 build/app/outputs/flutter-apk/app-release.apk
flutter build web --release   # Web，产物在 build/web
```

## 本机的 Android 构建环境

已经在本机配好，`flutter build apk` 可直接跑通。相关位置：

| 组件 | 位置 / 版本 |
| --- | --- |
| JDK | `F:\env\jdk17`（Microsoft OpenJDK 17.0.20） |
| Android SDK | `D:\env\android` |
| 编译用 SDK | platform android-36、build-tools 36.0.0 |
| NDK | `D:\env\android\ndk\28.2.13676358`（Flutter 的 Gradle 插件强制要求） |
| Android Studio | `F:\Software\as`（2021.3，**版本过老**，见下） |

Flutter 的配置已写好（`~/.flutter_settings`）：

```bash
flutter config --android-sdk="D:\env\android"
flutter config --jdk-dir="F:\env\jdk17"
```

### 为跑通构建做的三处调整

这三处都是本机网络/工具链导致的，换台机器通常不需要：

1. **`android/settings.gradle.kts` 与 `android/build.gradle.kts`**：本机访问 `maven.google.com` 会超时，改用等价的 `https://dl.google.com/dl/android/maven2/`。这是同一份 Google Maven 仓库，任何机器上都能用。

2. **`android/gradle.properties` 里的 `kotlin.incremental=false`**：Kotlin 2.4.0 的增量编译缓存在本机稳定报
   `Could not close incremental caches ... Storage ... is already registered`，
   关掉后构建正常。只影响编译速度，不影响产物；若换环境后可试着删掉这行。

3. **移除了 `windows/` 平台目录**：Flutter 会为 `windows/` 下的插件建符号链接（`shared_preferences_windows`、`path_provider_windows`），而这需要 Windows 开发者模式或管理员权限。本机没有开启，且本机也构建不了 Windows 桌面版（缺 Visual Studio），因此按需删除。

> 如果以后要做 Windows 桌面开发，建议在「设置 → 隐私和安全性 → 开发者选项」里打开**开发者模式**，然后 `flutter create --platforms=windows .` 恢复该平台。

### 关于 Android Studio

本机装的 Android Studio 是 **2021.3**，只支持到 AGP 7.x，而本项目的模板使用 **AGP 9.1.0 / Gradle 9.3.1 / Kotlin 2.4.0**，因此在新版 Android Studio（2025.2 及以上）之前，IDE 的 Gradle Sync 无法成功。编译 APK 请用命令行的 `flutter build apk --release`（Flutter 的标准做法，产物与 IDE 完全一致）。

## 应用图标

- 图形：`mdi:arm-flex`（屈臂肌肉），来自 **Material Design Icons**（作者 Pictogrammers），
  **Apache License 2.0** —— 可商用，但**必须保留署名并附带许可副本**。
- 底色：`#0E9F6E`，与 App 内主题色一致。

资源位置：

| 文件 | 说明 |
| --- | --- |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Android 8+ 的自适应图标 |
| `android/app/src/main/res/drawable/ic_launcher_foreground.xml` | 矢量前景（字形占 108dp 画布的 52%，留在安全区内） |
| `android/app/src/main/res/values/colors.xml` | 背景色 `ic_launcher_background` |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | 48 / 72 / 96 / 144 / 192 的传统图标，给 Android 7 及以下 |
| `android/app/src/main/res/mipmap-*/ic_launcher_round.png` | 同尺寸的圆形版本，供声明 `roundIcon` 的启动器使用 |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | iOS 全套 15 个尺寸（铺满方形、无透明通道，iOS 自己裁形状） |
| `web/icons/*`、`web/favicon.png` | Web 端图标（含 maskable 版本） |

Android 8 以上走矢量自适应图标，任何分辨率都不糊；换图标只需替换
`ic_launcher_foreground.xml` 里的 `pathData` 和 `colors.xml` 里的颜色。

### 开源许可（重要）

Flutter 只会自动收集 **pub 依赖**的许可并打进 `NOTICES`，手工放进 `res/` 与 `web/`
的图标**不在**自动收集范围内。因此图标的署名与许可正文写在了
`lib/legal/third_party_licenses.dart`，在 `main()` 里通过 `LicenseRegistry` 登记，
用户可在「历史记录 → 右上角 ⓘ → 开源许可」里查看。

改图标时如果换了别的图标集，**记得同步改这里**，否则会丢掉署名。

## 代码结构

```
lib/
├── main.dart                     应用入口，装配 AppStore 与主题
├── theme.dart                    主题（青绿主色）
├── models/
│   ├── exercise_item.dart        一台器械的规格：名称 / 组数 / 次数 / 重量 / 备注
│   ├── session_record.dart       某一天的训练记录，以及记录里每一项的完成状态
│   └── weekly_plan.dart          周计划模板，1~7 对应周一到周日
├── data/
│   ├── app_repository.dart       基于 shared_preferences 的 JSON 持久化
│   └── app_store.dart            全应用状态：周计划 + 历史记录 + 统计
├── pages/
│   ├── home_page.dart            底部导航（今日训练 / 周计划 / 历史记录）
│   ├── today_page.dart           当天清单与打卡
│   ├── plan_page.dart            按星期安排器械
│   ├── history_page.dart         历史列表、筛选与统计
│   └── session_detail_page.dart  某一天的训练详情
├── widgets/
│   ├── exercise_editor_sheet.dart 添加/编辑器械的底部面板
│   ├── exercise_tile.dart         清单项与计划项
│   └── empty_state.dart           空状态占位
└── utils/
    ├── dates.dart                日期与星期的中文格式化
    ├── equipment_presets.dart    常用器械名称
    └── ids.dart                  唯一 ID 生成
```

## 数据存储

数据保存在本机，不联网、不上传。

- 周计划：`shared_preferences` 里的 `weekly_plan_v1`，格式为 JSON。
- 训练记录：`shared_preferences` 里的 `sessions_v1`，以 `2026-10-07` 这样的日期为键。

用 `shared_preferences` 是因为它全平台通用（含 Web），而且这个应用的数据量很小 —— 每条记录只有几行文本。存储逻辑集中在 `AppRepository`，将来要换成 sqlite 或云端同步，只需要替换这一个类。

**周计划只往前看，历史只往后看。** 改动周计划会立刻同步到「今天及以后」的日子 —— 新增的器械自动补进来，组数/重量跟着更新，已完成的状态保留，当天临时加练的器械也留着。**过去的日期一律不套用周计划**：哪怕那天没有任何记录，也不会凭空出现今天才加进计划的器械；历史必须是当时练了什么就是什么。想补记过去某一天，翻到那天点「按周计划补记」，这是一次显式动作，之后的计划改动也不会再回头改写它。

## 测试

```bash
flutter analyze   # 静态检查
flutter test      # 单元测试 + Widget 测试
```

- `test/models_test.dart`：模型序列化、进度统计、日期工具。
- `test/app_store_test.dart`：计划的增删改复制、打卡与取消、历史排序、连续打卡、持久化往返。
- `test/widget_test.dart`：真实的界面流程 —— 在周计划里加器械 → 今日训练打卡 → 历史记录里看到，以及筛选、补记等场景。
