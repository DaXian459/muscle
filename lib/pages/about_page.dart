import 'package:flutter/material.dart';

/// 关于页：应用信息与开源许可入口。
///
/// 应用图标是 Apache-2.0 素材，许可要求分发时附带许可副本并保留署名，
/// 所以这里必须有一个用户可达的入口能看到它。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 与 pubspec.yaml 里的 version 保持一致，改版本时两边一起改。
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String repository = 'https://github.com/DaXian459/muscle';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('肌肉', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        '版本 $appVersion ($buildNumber)',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '按周安排训练计划，记录每天用到的器械，练完打勾，历史自动留存。',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('开源许可'),
            subtitle: const Text('Material Design Icons 等第三方素材的许可与署名'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '肌肉',
              applicationVersion: '$appVersion ($buildNumber)',
              applicationIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 44,
                  height: 44,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('项目主页'),
            subtitle: const Text(repository),
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('项目主页'),
                content: const SelectableText(repository),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
