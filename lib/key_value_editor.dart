import 'package:flutter/material.dart';

class KeyValueEditor extends StatefulWidget {
  final Map<String, String> initialData;
  final ValueChanged<Map<String, String>> onChanged;

  const KeyValueEditor({
    super.key,
    this.initialData = const {},
    required this.onChanged,
  });

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  late List<MapEntry<String, String>> entries;

  @override
  void initState() {
    super.initState();
    entries = widget.initialData.entries.toList();
  }

  void _notifyChange() {
    widget.onChanged(Map.fromEntries(entries));
  }

  void _addEntry() {
    setState(() {
      entries.add(const MapEntry('', ''));
      _notifyChange();
    });
  }

  void _removeEntry(int index) {
    setState(() {
      entries.removeAt(index);
      _notifyChange();
    });
  }

  void _updateEntryKey(int index, String newKey) {
    setState(() {
      final value = entries[index].value;
      entries[index] = MapEntry(newKey, value);
      _notifyChange();
    });
  }

  void _updateEntryValue(int index, String newValue) {
    setState(() {
      final key = entries[index].key;
      entries[index] = MapEntry(key, newValue);
      _notifyChange();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _updateEntryKey(index, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _updateEntryValue(index, value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeEntry(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addEntry,
          icon: const Icon(Icons.add),
          label: const Text('Добавить'),
        ),
      ],
    );
  }
}
