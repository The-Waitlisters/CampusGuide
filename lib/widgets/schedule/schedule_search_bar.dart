import 'package:flutter/material.dart';

class ScheduleSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const ScheduleSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        color: Colors.white,
      ),
      child: TextField(
        key: const Key('schedule_search_field'),
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter Course Name',
        ),
        style: const TextStyle(
          fontSize: 18,
        ),
      ),
    );
  }
}