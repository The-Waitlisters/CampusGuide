import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';

class SearchOverlay extends StatelessWidget {
  final TextEditingController controller;
  final bool showResults;
  final List<CampusBuilding> results;

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onTapField;
  final ValueChanged<CampusBuilding> onSelectResult;

  const SearchOverlay({
    super.key,
    required this.controller,
    required this.showResults,
    required this.results,
    required this.onChanged,
    required this.onClear,
    required this.onTapField,
    required this.onSelectResult,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 12,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search building...',
                  border: InputBorder.none,
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  ),
                ),
                onChanged: onChanged,
                onTap: onTapField,
              ),
            ),
          ),
          if (showResults) SearchResultsCard(results: results, onSelect: onSelectResult),
        ],
      ),
    );
  }
}

class SearchResultsCard extends StatelessWidget {
  final List<CampusBuilding> results;
  final ValueChanged<CampusBuilding> onSelect;

  const SearchResultsCard({
    super.key,
    required this.results,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final b = results[i];

          return ListTile(
            dense: true,
            title: Text(b.name),
            subtitle: (b.fullName != null && b.fullName!.trim().isNotEmpty)
                ? Text(b.fullName!)
                : null,
            onTap: () => onSelect(b),
          );
        },
      ),
    );
  }
}