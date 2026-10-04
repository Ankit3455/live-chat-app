import 'dart:io';

import 'package:availchat/services/media/media_validator.dart';
import 'package:flutter_test/flutter_test.dart';

// DEST-013: client-side type, size and duration checks before upload.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('media_validator'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(20, 0)];
  final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
  final webp = [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits];
  final heic = [0, 0, 0, 0x18, ...'ftyp'.codeUnits, ...'heic'.codeUnits];
  final m4a = [0, 0, 0, 0x20, ...'ftyp'.codeUnits, ...'M4A '.codeUnits];

  test('sniffs image types from magic bytes, not the extension', () async {
    expect(
      await MediaValidator.sniffImageMime(write('a.png', jpeg)),
      'image/jpeg',
    );
    expect(await MediaValidator.sniffImageMime(write('b', png)), 'image/png');
    expect(await MediaValidator.sniffImageMime(write('c', webp)), 'image/webp');
    expect(
      await MediaValidator.sniffImageMime(write('d.jpg', [1, 2, 3])),
      isNull,
    );
  });

  test('HEIC may be picked but not uploaded as-is', () async {
    final f = write('e.heic', heic);
    expect(await MediaValidator.isHeic(f), isTrue);
    expect(await MediaValidator.validateImageSource(f), isNull);
    expect(await MediaValidator.validateImageUpload(f), isNotNull);
  });

  test('rejects missing, empty and oversized images', () async {
    expect(
      await MediaValidator.validateImageUpload(File('${dir.path}/none')),
      isNotNull,
    );
    expect(
      await MediaValidator.validateImageUpload(write('empty', [])),
      isNotNull,
    );
    final big = write('big.jpg', jpeg);
    await big.writeAsBytes(
      List.filled(MediaValidator.maxImageBytes, 0),
      mode: FileMode.append,
    );
    expect(await MediaValidator.validateImageUpload(big), isNotNull);
    expect(
      await MediaValidator.validateImageUpload(write('ok.jpg', jpeg)),
      isNull,
    );
  });

  test('voice notes are 1 s to 2 min and must be MP4/M4A', () async {
    final f = write('v.m4a', m4a);
    expect(MediaValidator.maxVoiceSeconds, 120);
    expect(await MediaValidator.validateVoice(f, 0), isNotNull);
    expect(await MediaValidator.validateVoice(f, 1), isNull);
    expect(await MediaValidator.validateVoice(f, 120), isNull);
    expect(await MediaValidator.validateVoice(f, 121), isNotNull);
    expect(
      await MediaValidator.validateVoice(write('v.wav', jpeg), 10),
      isNotNull,
    );
  });
}
