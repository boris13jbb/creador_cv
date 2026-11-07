import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/features/templates/cv_templates.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:creador_cv/saas/config/plan_limits.dart';
import 'package:creador_cv/saas/config/saas_config.dart';
import 'package:creador_cv/saas/models/subscription_access.dart';
import 'package:creador_cv/saas/models/user_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

Resume _resume(int designIndex) {
  return Resume(
    id: 'cv-1',
    nombre: 'Juan Gabriel Burbano Bonifaz',
    perfil: 'Perfil',
    datosPersonales: const [],
    competencias: const [],
    idiomas: const [],
    experiencia: const [],
    formacion: const [],
    designIndex: designIndex,
  );
}

UserEntitlement _plan({
  required SubscriptionPlan plan,
  String status = 'active',
  String source = 'stripe',
}) {
  final now = DateTime.now();
  return UserEntitlement(
    uid: 'u1',
    plan: plan,
    subscriptionStatus: status,
    source: source,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('resolveSubscriptionAccess', () {
    test('Free confirmado', () {
      final entitlement = UserEntitlement.freeBootstrap('u1');
      expect(entitlement.isPro, isFalse);
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: entitlement,
      );
      expect(access, SubscriptionAccess.free);
      expect(access.isConfirmed, isTrue);
    });

    test('Pro activo confirmado', () {
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: _plan(plan: SubscriptionPlan.pro),
      );
      expect(access, SubscriptionAccess.pro);
      expect(_plan(plan: SubscriptionPlan.pro).isPro, isTrue);
    });

    test('Pro trialing confirmado', () {
      final entitlement = _plan(plan: SubscriptionPlan.pro, status: 'trialing');
      expect(entitlement.isPro, isTrue);
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: entitlement,
      );
      expect(access, SubscriptionAccess.pro);
      expect(CvTemplates.decideRender(4, access: access).renderIndex, 4);
    });

    test('suscripción vencida no es Pro', () {
      final entitlement = _plan(plan: SubscriptionPlan.pro, status: 'canceled');
      expect(entitlement.isPro, isFalse);
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: entitlement,
      );
      expect(access, SubscriptionAccess.free);
    });

    test('admin grant vigente es Pro', () {
      final now = DateTime.utc(2026, 11, 6, 12);
      final e = UserEntitlement(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        source: 'admin_grant',
        grantStartsAt: now.subtract(const Duration(days: 1)),
        grantExpiresAt: now.add(const Duration(days: 7)),
        grantModality: 'temporary',
        createdAt: now,
        updatedAt: now,
      );
      expect(e.isProAt(now: now), isTrue);
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: e,
      );
      expect(access, SubscriptionAccess.pro);
    });

    test('admin grant vencido no es Pro', () {
      final now = DateTime.utc(2026, 11, 6, 12);
      final e = UserEntitlement(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        source: 'admin_grant',
        grantExpiresAt: now.subtract(const Duration(hours: 1)),
        grantModality: 'temporary',
        createdAt: now,
        updatedAt: now,
      );
      expect(e.isProAt(now: now), isFalse);
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: e,
      );
      expect(access, SubscriptionAccess.free);
    });

    test('datos inválidos de grant no otorgan Pro', () {
      final now = DateTime.utc(2026, 11, 6);
      final e = UserEntitlement.fromMap({
        'uid': 'u1',
        'plan': 'pro',
        'subscriptionStatus': 'active',
        'source': 'admin_grant',
        'grantModality': 'temporary',
        'grantExpiresAt': '%%%',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(e.grantWindowInvalid, isTrue);
      expect(e.isPro, isFalse);
      expect(
        resolveSubscriptionAccess(
          authenticated: true,
          loading: false,
          planUnconfirmed: false,
          entitlement: e,
        ),
        SubscriptionAccess.free,
      );
    });

    test('verificación pendiente no se trata como Free', () {
      final access = resolveSubscriptionAccess(
        authenticated: true,
        loading: true,
        planUnconfirmed: false,
        entitlement: null,
      );
      expect(access, SubscriptionAccess.pending);
      expect(access.isUnresolved, isTrue);
      final decision = CvTemplates.decideRender(4, access: access);
      expect(decision.holdForPlan, isTrue);
      expect(decision.renderIndex, isNull);
      expect(decision.savedIndex, 4);
    });

    test('error de lectura no confirma Free ni pisa un Pro ya leído', () {
      final failed = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: true,
        entitlement: null,
      );
      expect(failed, SubscriptionAccess.error);

      final kept = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: _plan(plan: SubscriptionPlan.pro),
      );
      expect(kept, SubscriptionAccess.pro);

      final syntheticFree = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: true,
        entitlement: UserEntitlement.freeBootstrap('u1'),
      );
      expect(syntheticFree, SubscriptionAccess.error);
    });

    test('recuperación: tras error, entitlement confirmado vuelve a Pro', () {
      final afterError = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: true,
        entitlement: null,
      );
      expect(afterError, SubscriptionAccess.error);

      final recovered = resolveSubscriptionAccess(
        authenticated: true,
        loading: false,
        planUnconfirmed: false,
        entitlement: _plan(plan: SubscriptionPlan.pro),
      );
      expect(recovered, SubscriptionAccess.pro);
    });
  });

  group('PlanLimits / usage Rules policy', () {
    test('Free con 0 CV puede crear', () {
      expect(PlanLimits.canCreateResume(currentCount: 0, isPro: false), isTrue);
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: 0),
        isTrue,
      );
    });

    test('Free con 2 CV puede crear', () {
      expect(PlanLimits.canCreateResume(currentCount: 2, isPro: false), isTrue);
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: 2),
        isTrue,
      );
    });

    test('Free con 3 CV no puede crear', () {
      expect(
        PlanLimits.canCreateResume(currentCount: 3, isPro: false),
        isFalse,
      );
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: 3),
        isFalse,
      );
      expect(PlanLimits.freeMaxCvs, SaasConfig.freeMaxCvs);
    });

    test('Free sin documento usage no autoriza create', () {
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: false, resumeCount: null),
        isFalse,
      );
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: false, resumeCount: 0),
        isFalse,
      );
    });

    test('Free con contador inconsistente (negativo / null) deniega', () {
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: null),
        isFalse,
      );
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: -1),
        isFalse,
      );
      expect(
        PlanLimits.canCreateResume(currentCount: -1, isPro: false),
        isFalse,
      );
    });

    test('Pro con más de 3 CV puede crear', () {
      expect(PlanLimits.canCreateResume(currentCount: 50, isPro: true), isTrue);
    });

    test('dos creaciones en el límite: solo cabe una más con count=2', () {
      // Simula la ventana de Rules: ambas leen count=2 → ambas pasan Rules;
      // el contador materializado tras sync deja count=3 y bloquea la 4ª.
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: 2),
        isTrue,
      );
      expect(
        PlanLimits.freeRulesAllowCreate(usageExists: true, resumeCount: 3),
        isFalse,
      );
    });
  });

  group('plantillas / PDF con pending y error', () {
    test('CV existente con designIndex 4 se reabre sin cambiar el índice', () {
      final original = _resume(4);
      final stored = Resume.fromMap(original.toFirestoreMap(userId: 'owner'));
      expect(stored.designIndex, 4);

      final pending = CvTemplates.decideRender(
        stored.designIndex,
        access: SubscriptionAccess.pending,
      );
      expect(stored.designIndex, 4);
      expect(pending.savedIndex, 4);
      expect(pending.holdForPlan, isTrue);

      final errored = CvTemplates.decideRender(
        stored.designIndex,
        access: SubscriptionAccess.error,
      );
      expect(errored.holdForPlan, isTrue);
      expect(errored.savedIndex, 4);

      final reopened = Resume.fromMap(stored.toFirestoreMap(userId: 'owner'));
      expect(reopened.designIndex, 4);
      expect(
        CvTemplates.decideRender(
          reopened.designIndex,
          access: SubscriptionAccess.pro,
        ).renderIndex,
        4,
      );
    });

    test(
      'Preview y PDF usan la misma decisión y no generan si el plan está pendiente',
      () async {
        final pending = CvTemplates.decideRender(
          4,
          access: SubscriptionAccess.pending,
        );
        expect(pending.holdForPlan, isTrue);
        await expectLater(
          ResumePdfService.generateResumePdf(
            _resume(4),
            access: SubscriptionAccess.pending,
          ),
          throwsA(isA<PlanVerificationPending>()),
        );

        await expectLater(
          ResumePdfService.generateResumePdf(
            _resume(4),
            access: SubscriptionAccess.error,
          ),
          throwsA(isA<PlanVerificationPending>()),
        );

        final pro = CvTemplates.decideRender(4, access: SubscriptionAccess.pro);
        expect(pro.renderIndex, 4);
        expect(pro.keptSavedDesign, isTrue);
      },
    );

    test(
      'Free confirmado aplica el fallback sin borrar el índice guardado',
      () {
        final entitlement = UserEntitlement.freeBootstrap('u1');
        final access = resolveSubscriptionAccess(
          authenticated: true,
          loading: false,
          planUnconfirmed: false,
          entitlement: entitlement,
        );
        expect(access, SubscriptionAccess.free);
        final decision = CvTemplates.decideRender(4, access: access);
        expect(decision.savedIndex, 4);
        expect(decision.renderIndex, CvTemplates.freeFallbackIndex);
        expect(decision.holdForPlan, isFalse);
      },
    );

    test('los índices 0 a 4 no cambian de regla', () {
      for (var index = 0; index <= 4; index++) {
        final pro = CvTemplates.decideRender(
          index,
          access: SubscriptionAccess.pro,
        );
        expect(pro.renderIndex, index, reason: 'Pro debe dibujar $index');

        final free = CvTemplates.decideRender(
          index,
          access: SubscriptionAccess.free,
        );
        final expectedFree = CvTemplates.requiresPro(index)
            ? CvTemplates.freeFallbackIndex
            : index;
        expect(free.renderIndex, expectedFree, reason: 'Free dibuja $index');
        expect(free.savedIndex, index);

        for (final unresolved in [
          SubscriptionAccess.pending,
          SubscriptionAccess.error,
        ]) {
          final hold = CvTemplates.decideRender(index, access: unresolved);
          expect(hold.savedIndex, index);
          if (CvTemplates.requiresPro(index)) {
            expect(hold.holdForPlan, isTrue, reason: '$unresolved $index');
          } else {
            expect(hold.renderIndex, index, reason: 'Free sigue disponible');
          }
        }
      }
    });
  });
}
