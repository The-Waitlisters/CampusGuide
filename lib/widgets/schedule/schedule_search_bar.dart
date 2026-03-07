import 'package:flutter/material.dart';

class ScheduleSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const ScheduleSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
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
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.characters,
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