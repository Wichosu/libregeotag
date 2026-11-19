import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:libregeotag/app_info.dart';

void main() {
  test('the shown version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final line = pubspec
        .split('\n')
        .firstWhere((line) => line.trimLeft().startsWith('version:'));

    // `0.1.0+1` — the build number is not shown to the user.
    final version = line.split(':')[1].trim().split('+').first;

    expect(appVersion, version);
  });
}
