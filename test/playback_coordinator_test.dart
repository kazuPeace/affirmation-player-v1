import 'package:affirmation_player/models/affirmation.dart';
import 'package:affirmation_player/models/playback_config.dart';
import 'package:affirmation_player/services/audio/playback_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaybackCoordinator', () {
    final coordinator = PlaybackCoordinator();

    test('YOU mode renders with あなたは prefix', () {
      const sentence = AffirmationSentence(
        id: '1',
        order: 0,
        subjectText: '私は',
        predicateText: '大丈夫',
      );
      final config = PlaybackConfig.defaults().copyWith(
        mode: AffirmationMode.you,
      );

      expect(coordinator.renderSentence(sentence, config), 'あなたは大丈夫。');
    });

    test('normal mode falls back to default first person', () {
      const sentence = AffirmationSentence(
        id: '1',
        order: 0,
        subjectText: '',
        predicateText: '落ち着いて進める',
      );
      final config = PlaybackConfig.defaults().copyWith(
        defaultFirstPerson: '僕は',
      );

      expect(coordinator.renderSentence(sentence, config), '僕は落ち着いて進める。');
    });

    test('sentence can opt out of config first person', () {
      const sentence = AffirmationSentence(
        id: '1',
        order: 0,
        subjectText: '',
        predicateText: '静かに整っていく',
        useConfigFirstPerson: false,
      );
      final config = PlaybackConfig.defaults().copyWith(
        defaultFirstPerson: '私は',
      );

      expect(coordinator.renderSentence(sentence, config), '静かに整っていく。');
    });
  });
}
