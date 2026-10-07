import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_item.dart';
import '../utils/equipment_presets.dart';
import '../utils/ids.dart';

/// 编辑器返回的结果：保存了一项，或者要求删除这一项。
class ExerciseEditorResult {
  const ExerciseEditorResult.saved(ExerciseItem this.item) : deleted = false;
  const ExerciseEditorResult.deleted() : item = null, deleted = true;

  final ExerciseItem? item;
  final bool deleted;
}

/// 弹出「添加 / 编辑器械」底部面板，取消时返回 null。
Future<ExerciseEditorResult?> showExerciseEditor(
  BuildContext context, {
  ExerciseItem? initial,
  String title = '添加器械',
}) {
  return showModalBottomSheet<ExerciseEditorResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _ExerciseEditorSheet(initial: initial, title: title),
  );
}

class _ExerciseEditorSheet extends StatefulWidget {
  const _ExerciseEditorSheet({required this.initial, required this.title});

  final ExerciseItem? initial;
  final String title;

  @override
  State<_ExerciseEditorSheet> createState() => _ExerciseEditorSheetState();
}

class _ExerciseEditorSheetState extends State<_ExerciseEditorSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _weightController = TextEditingController(
    text: widget.initial?.weight == null
        ? ''
        : formatWeight(widget.initial!.weight!),
  );
  late final TextEditingController _noteController =
      TextEditingController(text: widget.initial?.note ?? '');
  late int _sets = widget.initial?.sets ?? 3;
  late int _reps = widget.initial?.reps ?? 12;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    setState(() {
      _nameController.text = preset;
      _nameController.selection =
          TextSelection.collapsed(offset: preset.length);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写器械名称')),
      );
      return;
    }
    final weightText = _weightController.text.trim();
    final item = ExerciseItem(
      id: widget.initial?.id ?? newId(),
      name: name,
      sets: _sets,
      reps: _reps,
      weight: weightText.isEmpty ? null : double.tryParse(weightText),
      note: _noteController.text.trim(),
    );
    Navigator.pop(context, ExerciseEditorResult.saved(item));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这项训练？'),
        content: Text('「${widget.initial?.name ?? ''}」将被移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.pop(context, const ExerciseEditorResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '器械 / 动作名称',
                hintText: '例如：高位下拉',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '常用器械',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final preset in kEquipmentPresets)
                  ActionChip(
                    label: Text(preset),
                    onPressed: () => _applyPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _NumberStepper(
                    label: '组数',
                    value: _sets,
                    onChanged: (value) => setState(() => _sets = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberStepper(
                    label: '每组次数',
                    value: _reps,
                    onChanged: (value) => setState(() => _reps = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: '重量 kg（自重训练可留空）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '例如：最后一组力竭 / 座位调第 3 档',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                if (widget.initial != null) ...<Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 组数 / 次数的加减控件，范围固定在 1 ~ 99。
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static const int _min = 1;
  static const int _max = 99;

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: value > _min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
                visualDensity: VisualDensity.compact,
                tooltip: '减少$label',
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: value < _max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
                tooltip: '增加$label',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
