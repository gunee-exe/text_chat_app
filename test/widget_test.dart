// Unit tests for the username rules. These don't touch Firebase, so they run
// fast and offline. (A full boot test would need Firebase initialised.)

import 'package:flutter_test/flutter_test.dart';
import 'package:textify/features/users/data/user_repository.dart';

void main() {
  group('username validation', () {
    test('accepts a simple lowercase username', () {
      expect(UserRepository.validate('sara_khan'), isNull);
    });

    test('normalizes case', () {
      expect(UserRepository.normalize('SaraKhan'), 'sarakhan');
    });

    test('rejects spaces', () {
      expect(UserRepository.validate('sara khan'), isNotNull);
    });

    test('rejects too-short names', () {
      expect(UserRepository.validate('ab'), isNotNull);
    });

    test('rejects illegal characters', () {
      expect(UserRepository.validate('sara!'), isNotNull);
    });

    test('empty is rejected', () {
      expect(UserRepository.validate('   '), isNotNull);
    });
  });
}
