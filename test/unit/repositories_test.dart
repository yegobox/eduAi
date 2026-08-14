import 'package:eduai/core/error/failure.dart';
import 'package:eduai/core/storage/key_value_cache.dart';
import 'package:eduai/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:eduai/features/billing/data/datasources/billing_seed_data_source.dart';
import 'package:eduai/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:eduai/features/lessons/data/datasources/lessons_seed_data_source.dart';
import 'package:eduai/features/lessons/data/repositories/lessons_repository_impl.dart';
import 'package:eduai/features/lessons/domain/entities/lesson.dart';
import 'package:eduai/features/parent/data/datasources/parent_seed_data_source.dart';
import 'package:eduai/features/parent/data/repositories/parent_repository_impl.dart';
import 'package:eduai/features/parent/domain/entities/parent_entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KeyValueCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = KeyValueCache();
  });

  group('LessonsRepositoryImpl', () {
    LessonsRepositoryImpl repo() => LessonsRepositoryImpl(
      seedSource: const LessonsSeedDataSource(),
      kvCache: cache,
    );

    test('serves the bundled catalog with clean local state', () async {
      final result = await repo().fetchCatalog();
      final lessons = result.valueOrNull!;
      expect(lessons, isNotEmpty);
      expect(lessons.every((l) => !l.downloaded), isTrue);
      expect(lessons.every((l) => !l.completed), isTrue);
      // Every grade band the filter row offers has at least one lesson.
      for (final band in GradeBand.values) {
        expect(
          lessons.where((l) => l.band == band),
          isNotEmpty,
          reason: band.label,
        );
      }
    });

    test('download toggles round-trip through the device cache', () async {
      final r = repo();
      final on = await r.setDownloaded('l2', true);
      expect(on.valueOrNull?.downloaded, isTrue);

      final afterOn = (await r.fetchCatalog()).valueOrNull!;
      expect(afterOn.firstWhere((l) => l.id == 'l2').downloaded, isTrue);
      // Only that lesson changed.
      expect(afterOn.where((l) => l.downloaded), hasLength(1));

      await r.setDownloaded('l2', false);
      final afterOff = (await r.fetchCatalog()).valueOrNull!;
      expect(afterOff.firstWhere((l) => l.id == 'l2').downloaded, isFalse);
    });

    test('mark-complete is idempotent and independent of download', () async {
      final r = repo();
      await r.setDownloaded('l1', true);
      await r.markComplete('l1');
      final again = await r.markComplete('l1');

      // The returned lesson carries both flags, not just the one just touched.
      expect(again.valueOrNull?.completed, isTrue);
      expect(again.valueOrNull?.downloaded, isTrue);

      final catalog = (await r.fetchCatalog()).valueOrNull!;
      expect(catalog.where((l) => l.completed), hasLength(1));
    });

    test('rejects an unknown lesson id', () async {
      final result = await repo().setDownloaded('nope', true);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        (await repo().markComplete('nope')).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('survives a corrupted cache entry', () async {
      await cache.setJson('lessons_downloaded', {'not': 'a list'});
      final lessons = (await repo().fetchCatalog()).valueOrNull!;
      expect(lessons.every((l) => !l.downloaded), isTrue);
    });
  });

  group('ParentRepositoryImpl', () {
    ParentRepositoryImpl repo() => ParentRepositoryImpl(
      seedSource: const ParentSeedDataSource(),
      kvCache: cache,
    );

    test('lists children with derived initials and first names', () async {
      final children = (await repo().fetchChildren()).valueOrNull!;
      expect(children, hasLength(2));
      expect(children.first.initials, 'AK');
      expect(children.first.firstName, 'Alice');
    });

    test('appends a sent message to the thread in time order', () async {
      final r = repo();
      final before = (await r.fetchMessages('k1')).valueOrNull!;
      await r.sendMessage(childId: 'k1', text: '  Thank you  ');

      final after = (await r.fetchMessages('k1')).valueOrNull!;
      expect(after, hasLength(before.length + 1));
      expect(after.last.text, 'Thank you');
      expect(after.last.fromParent, isTrue);
      // The thread stays chronological.
      for (var i = 1; i < after.length; i++) {
        expect(after[i].at.isBefore(after[i - 1].at), isFalse);
      }
    });

    test('refuses an empty message', () async {
      final result = await repo().sendMessage(childId: 'k1', text: '   ');
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('threads are per child', () async {
      final r = repo();
      await r.sendMessage(childId: 'k1', text: 'For Alice');
      final other = (await r.fetchMessages('k2')).valueOrNull!;
      expect(other.any((m) => m.text == 'For Alice'), isFalse);
    });

    test('credits a top-up once per gateway reference', () async {
      final r = repo();
      const pack = TopupPack(
        id: 'small',
        label: 'Small',
        sessions: 20,
        priceRwf: 500,
      );

      expect(
        (await r.creditTopup(pack: pack, paymentReference: 'ref-1')).isSuccess,
        isTrue,
      );
      // Polling the gateway twice must not double-credit.
      expect(
        (await r.creditTopup(pack: pack, paymentReference: 'ref-1')).isSuccess,
        isTrue,
      );

      final stored = await cache.getJson('parent_topup_credits') as List;
      expect(stored, hasLength(1));
      expect((stored.single as Map)['sessions'], 20);
    });

    test('never credits without a payment reference', () async {
      const pack = TopupPack(
        id: 'small',
        label: 'Small',
        sessions: 20,
        priceRwf: 500,
      );
      final result = await repo().creditTopup(
        pack: pack,
        paymentReference: '  ',
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await cache.getJson('parent_topup_credits'), isNull);
    });

    test('exposes the school plan and the optional top-up packs', () async {
      final r = repo();
      expect((await r.fetchPlan()).valueOrNull?.tier, 'Growth');
      expect((await r.fetchTopupPacks()).valueOrNull, hasLength(3));
    });
  });

  group('BillingRepositoryImpl', () {
    // No Supabase client, which is the "unconfigured build" path.
    BillingRepositoryImpl repo() => BillingRepositoryImpl(
      remoteSource: BillingRemoteDataSource(null),
      seedSource: const BillingSeedDataSource(),
    );

    test('serves the built-in price list when there is no backend', () async {
      final tiers = (await repo().fetchTiers()).valueOrNull!;
      expect(tiers, hasLength(3));
      expect(tiers.map((t) => t.id), containsAll(['starter', 'growth', 'district']));
      // Seat ceilings come through, because the tier switch is validated
      // against them.
      expect(tiers.firstWhere((t) => t.id == 'growth').maxSeats, 800);
      expect(tiers.firstWhere((t) => t.id == 'district').maxSeats, isNull);
    });

    test('reports no payments rather than inventing paid invoices', () async {
      // The old seed source claimed three settled invoices, which told a
      // school its licence was paid when nothing had been collected.
      expect((await repo().fetchInvoices()).valueOrNull, isEmpty);
    });

    test('still serves usage for the renewal conversation', () async {
      expect((await repo().fetchUsage()).valueOrNull?.topSubject, 'Mathematics');
    });
  });
}
