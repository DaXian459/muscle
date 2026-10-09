import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_item.dart';

/// 弹出「记录重量」对话框，用来随手补上当天用的配重。
///
/// 返回输入框里的**原文**（可能是空串，表示清掉重量）；用户取消时返回 null。
/// 之所以回传字符串而不是 double —— 留空保存和取消都会得到 null，分不开，
/// 而这两种意图的结果正好相反。
Future<String?> showWeightEditor(
  BuildContext context, {
  required String name,
  double? weight,
}) {
  var typed = weight == null || weight <= 0 ? '' : formatWeight(weight);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('「$name」的重量'),
      content: TextFormField(
        initialValue: typed,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        decoration: const InputDecoration(
          suffixText: 'kg',
          hintText: '留空表示不记重量',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => typed = value,
        onFieldSubmitted: (_) => Navigator.pop(dialogContext, typed),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, typed),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// 把对话框返回的原文转成重量：空串或解析不出来都当作用户要清掉重量。
double? parseWeightInput(String? text) {
  final trimmed = (text ?? '').trim();
  if (trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed);
  return value != null && value > 0 ? value : null;
}
