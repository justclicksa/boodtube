import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttube_poc/data/local/preferences/settings_repository_impl.dart';
import 'package:smarttube_poc/domain/entities/sponsor_segment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SponsorBlock settings migration', () {
    test('a fresh install gets the upstream defaults', () {
      final actions = SettingsRepository.migrateSponsorActions();

      expect(actions[SponsorCategory.sponsor], SegmentAction.skip);
      expect(actions[SponsorCategory.musicOffTopic], SegmentAction.skip);
      // Filler ships disabled upstream: it is the aggressive one.
      expect(actions[SponsorCategory.filler], SegmentAction.none);
    });

    test('ticked categories with auto-skip on become skip', () {
      final actions = SettingsRepository.migrateSponsorActions(
        legacyCategories: 'sponsor,intro,filler',
        legacyAutoSkip: true,
      );

      expect(actions[SponsorCategory.sponsor], SegmentAction.skip);
      expect(actions[SponsorCategory.intro], SegmentAction.skip);
      // Ticked by the user, so it survives its own default.
      expect(actions[SponsorCategory.filler], SegmentAction.skip);
      expect(actions[SponsorCategory.outro], SegmentAction.none);
      expect(actions[SponsorCategory.musicOffTopic], SegmentAction.none);
    });

    test('ticked categories with auto-skip off become a button', () {
      final actions = SettingsRepository.migrateSponsorActions(
        legacyCategories: 'sponsor,selfPromo',
        legacyAutoSkip: false,
      );

      expect(actions[SponsorCategory.sponsor], SegmentAction.showButton);
      expect(actions[SponsorCategory.selfPromo], SegmentAction.showButton);
      expect(actions[SponsorCategory.intro], SegmentAction.none);
    });

    test('auto-skip alone migrates the old default category list', () {
      final actions = SettingsRepository.migrateSponsorActions(
        legacyAutoSkip: true,
      );

      expect(actions[SponsorCategory.sponsor], SegmentAction.skip);
      expect(actions[SponsorCategory.interaction], SegmentAction.skip);
      // Never part of the old default list.
      expect(actions[SponsorCategory.musicOffTopic], SegmentAction.none);
    });

    test('unknown category names are ignored, not defaulted to sponsor', () {
      final actions = SettingsRepository.migrateSponsorActions(
        legacyCategories: 'chapter,not_a_category',
        legacyAutoSkip: true,
      );

      expect(
        actions.values.every((a) => a == SegmentAction.none),
        isTrue,
      );
    });

    test('load() migrates the legacy keys on first run', () async {
      SharedPreferences.setMockInitialValues({
        'settings.sponsor_categories': 'sponsor,outro',
        'settings.auto_skip_sponsors': true,
      });
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      final settings = repository.load();

      expect(settings.actionFor(SponsorCategory.sponsor), SegmentAction.skip);
      expect(settings.actionFor(SponsorCategory.outro), SegmentAction.skip);
      expect(settings.actionFor(SponsorCategory.intro), SegmentAction.none);
      // The derived views the older screens read still line up.
      expect(settings.sponsorCategories, {
        SponsorCategory.sponsor,
        SponsorCategory.outro,
      });
      expect(settings.autoSkipSponsors, isTrue);
    });

    test('a stored action map wins over the legacy keys', () async {
      SharedPreferences.setMockInitialValues({
        'settings.sponsor_actions': 'sponsor:showButton,intro:none',
        'settings.sponsor_categories': 'sponsor,intro,outro',
        'settings.auto_skip_sponsors': true,
      });
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      final settings = repository.load();

      expect(
        settings.actionFor(SponsorCategory.sponsor),
        SegmentAction.showButton,
      );
      expect(settings.actionFor(SponsorCategory.intro), SegmentAction.none);
      // Absent from the stored map: falls back to its own default rather
      // than silently doing nothing.
      expect(settings.actionFor(SponsorCategory.outro), SegmentAction.skip);
    });

    test('saving an action persists it and mirrors the legacy keys',
        () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences);

      await repository.setSponsorAction(
        SponsorCategory.sponsor,
        SegmentAction.showButton,
      );
      await repository.setSponsorAction(
        SponsorCategory.intro,
        SegmentAction.none,
      );

      expect(
        repository.load().actionFor(SponsorCategory.sponsor),
        SegmentAction.showButton,
      );
      expect(
        repository.load().actionFor(SponsorCategory.intro),
        SegmentAction.none,
      );
      final legacy = preferences.getString('settings.sponsor_categories')!;
      expect(legacy.split(','), isNot(contains('intro')));
      expect(legacy.split(','), contains('sponsor'));
    });

    test('the legacy auto-skip switch moves every enabled category',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      await repository.setAutoSkipSponsors(false);

      final settings = repository.load();
      expect(
        settings.actionFor(SponsorCategory.sponsor),
        SegmentAction.showButton,
      );
      // Disabled stays disabled — the switch is not an enable-all.
      expect(settings.actionFor(SponsorCategory.filler), SegmentAction.none);
      expect(settings.autoSkipSponsors, isFalse);
    });

    test('toggling a category off and on keeps the prevailing action',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      await repository.toggleSponsorCategory(SponsorCategory.sponsor, false);
      expect(
        repository.load().actionFor(SponsorCategory.sponsor),
        SegmentAction.none,
      );

      await repository.toggleSponsorCategory(SponsorCategory.sponsor, true);
      expect(
        repository.load().actionFor(SponsorCategory.sponsor),
        SegmentAction.skip,
      );
    });

    test('the fetch list adds the two informational categories', () {
      const settings = AppSettings(
        sponsorActions: {SponsorCategory.sponsor: SegmentAction.skip},
      );

      expect(settings.sponsorFetchCategories, {
        SponsorCategory.sponsor,
        SponsorCategory.highlight,
        SponsorCategory.exclusiveAccess,
      });
    });
  });
}
