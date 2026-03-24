
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

typedef MarkerImageLoader = Future<Uint8List> Function(String path, int width);

Future<Uint8List> defaultMarkerImageLoader(String path, int width) async {
  ByteData data = await rootBundle.load(path);
  ui.Codec codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetHeight: width,
  );
  ui.FrameInfo fi = await codec.getNextFrame();
  return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
}