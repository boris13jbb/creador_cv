import 'package:creador_cv/saas/config/saas_config.dart';
import 'package:creador_cv/saas/models/saas_user_profile.dart';
import 'package:creador_cv/saas/models/user_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserEntitlement', () {
    test('bootstrap free no es Pro', () {
      final e = UserEntitlement.freeBootstrap('u1');
      expect(e.plan, SubscriptionPlan.free);
      expect(e.isPro, isFalse);
      expect(e.source, 'client_bootstrap');
      expect(e.maxCvs, SaasConfig.freeMaxCvs);
    });

    test('Pro activo es Pro', () {
      final now = DateTime.now();
      final e = UserEntitlement(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        source: 'legacy_migration',
        createdAt: now,
        updatedAt: now,
      );
      expect(e.isPro, isTrue);
      expect(e.maxCvs > SaasConfig.freeMaxCvs, isTrue);
    });

    test('Pro canceled no es Pro', () {
      final now = DateTime.now();
      final e = UserEntitlement(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'canceled',
        createdAt: now,
        updatedAt: now,
      );
      expect(e.isPro, isFalse);
    });

    test('migración legacy copia plan Pro', () {
      final e = UserEntitlement.fromLegacyUserMap('u1', {
        'plan': 'pro',
        'subscriptionStatus': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(e.plan, SubscriptionPlan.pro);
      expect(e.source, 'legacy_migration');
      expect(e.isPro, isTrue);
    });

    test('toMap/fromMap redondo', () {
      final original = UserEntitlement.freeBootstrap('u2');
      final copy = UserEntitlement.fromMap(original.toMap());
      expect(copy.uid, original.uid);
      expect(copy.plan, original.plan);
      expect(copy.subscriptionStatus, original.subscriptionStatus);
      expect(copy.schemaVersion, 1);
    });
  });

  group('SaasUserProfile', () {
    test('toWritableMap no incluye plan', () {
      final now = DateTime.now();
      final p = SaasUserProfile(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Ana',
        createdAt: now,
        updatedAt: now,
      );
      final map = p.toWritableMap();
      expect(map.containsKey('plan'), isFalse);
      expect(map.containsKey('subscriptionStatus'), isFalse);
      expect(map['schemaVersion'], 1);
    });

    test('fromMap conserva campos legacy sin exponerlos en writable', () {
      final p = SaasUserProfile.fromMap({
        'uid': 'u1',
        'email': 'a@b.com',
        'displayName': 'Ana',
        'plan': 'pro',
        'subscriptionStatus': 'active',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(p.hasLegacySubscriptionFields, isTrue);
      expect(p.legacyPlan, 'pro');
      expect(p.toWritableMap().containsKey('plan'), isFalse);
    });
  });
}
