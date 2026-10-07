import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muscle/legal/third_party_licenses.dart';

void main() {
  setUp(registerThirdPartyLicenses);

  test('应用图标的许可已登记到 LicenseRegistry', () async {
    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Material Design Icons（应用图标）'))
        .toList();

    expect(entries, isNotEmpty, reason: '图标是 Apache-2.0 素材，必须登记许可');
  });

  test('许可正文包含署名与 Apache-2.0 全文', () async {
    final entry = await LicenseRegistry.licenses
        .firstWhere((item) => item.packages.contains('Material Design Icons（应用图标）'));
    final text = entry.paragraphs.map((paragraph) => paragraph.text).join('\n');

    // 署名：作者与来源
    expect(text, contains('Pictogrammers'));
    expect(text, contains('Templarian/MaterialDesign'));
    // 改了什么也要写清楚（Apache-2.0 第 4 条 b）
    expect(text, contains('改动说明'));
    // 许可副本：两段正文都要在
    expect(text, contains('Pictogrammers Free License'));
    expect(text, contains('Apache License'));
    expect(text, contains('Version 2.0, January 2004'));
    expect(text, contains('END OF TERMS AND CONDITIONS'));
  });
}
