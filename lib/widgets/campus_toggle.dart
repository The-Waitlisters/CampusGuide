import 'package:flutter/material.dart';
import '../models/campus.dart';

class CampusToggle extends StatelessWidget {
  const CampusToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Campus selected;
  final ValueChanged<Campus> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Campus>(
      segments: const <ButtonSegment<Campus>>[
        ButtonSegment<Campus>(
          value: Campus.sgw,
          label: Text('SGW'),
        ),
        ButtonSegment<Campus>(
          value: Campus.loyola,
          label: Text('Loyola'),
        ),
      ],
      selected: <Campus>{selected},
      onSelectionChanged: (Set<Campus> selection) {
        if (selection.isEmpty) {
          return;
        }
        onChanged(selection.first);
      },
      showSelectedIcon: false,
    );
  }
}
