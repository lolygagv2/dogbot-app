// Regenerate every launcher icon from assets/icons/app_icon.png.
//
// iOS: the appiconset uses a hand-managed Contents.json with custom
// icon-ios-* / icon-mac-* / icon-watchos-* names. flutter_launcher_icons
// writes its own Icon-App-* names and never updates that Contents.json, so
// its output is orphaned (shipped a stale icon on builds 142/143). This
// script reads Contents.json and writes exactly the files it references, at
// size x scale, RGB with no alpha (App Store rejects alpha, ITMS-90717).
//
// Android: writes mipmap-*/ic_launcher.png at the standard densities.
//
// Run from the repo root:  dart run tool/regen_icons.dart
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _source = 'assets/icons/app_icon.png';
const _iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _androidRes = 'android/app/src/main/res';
const _androidDensities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

void main() {
  final src = img.decodeImage(File(_source).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode $_source');
    exit(1);
  }
  stdout.writeln('Source: ${src.width}x${src.height} channels=${src.numChannels}');
  if (src.width != src.height) {
    stderr.writeln('Source must be square');
    exit(1);
  }

  img.Image resized(int px) => img.copyResize(src,
      width: px, height: px, interpolation: img.Interpolation.cubic);

  // --- iOS / macOS / watchOS: whatever Contents.json references ---
  final contents = jsonDecode(File('$_iosDir/Contents.json').readAsStringSync())
      as Map<String, dynamic>;
  var iosCount = 0;
  for (final raw in contents['images'] as List) {
    final e = raw as Map<String, dynamic>;
    final filename = e['filename'] as String?;
    if (filename == null) continue;
    final size = double.parse((e['size'] as String).split('x').first);
    final scale =
        int.parse(((e['scale'] as String?) ?? '1x').replaceAll('x', ''));
    final px = (size * scale).round();
    final out = resized(px).convert(numChannels: 3); // strip alpha
    File('$_iosDir/$filename').writeAsBytesSync(img.encodePng(out));
    iosCount++;
  }
  stdout.writeln('iOS/mac/watchOS: wrote $iosCount files referenced by Contents.json');

  // --- Android ---
  _androidDensities.forEach((density, px) {
    final out = resized(px);
    File('$_androidRes/mipmap-$density/ic_launcher.png')
        .writeAsBytesSync(img.encodePng(out));
  });
  stdout.writeln('Android: wrote ${_androidDensities.length} mipmap densities');
}
