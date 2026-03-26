import 'package:flutter/material.dart';


class PoiToggle extends StatelessWidget {
  const PoiToggle({
    super.key,
    required this.onOpenPoiOptions,
  });


  final VoidCallback onOpenPoiOptions;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
          onPressed:
            onOpenPoiOptions
          ,
          child: Text("POIs"),
        );
  }
}