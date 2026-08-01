import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/plan_limits.dart';
import '../config/saas_config.dart';
import 'auth_service.dart';

/// Resultado de sincronizar el contador servidor `usage/{uid}`.
class ResumeUsageSnapshot {
  const ResumeUsageSnapshot({
    required this.resumeCount,
    required this.isPro,
    required this.canCreate,
  });

  final int resumeCount;
  final bool isPro;
  final bool canCreate;
}

/// Cliente HTTP de límites Free en servidor (`syncResumeUsage`).
class UsageService {
  UsageService._();
  static final instance = UsageService._();

  Uri get _endpoint {
    final base = SaasConfig.billingFunctionsBaseUrl.replaceAll(
      RegExp(r'/$'),
      '',
    );
    return Uri.parse('$base/syncResumeUsage');
  }

  /// Recuenta CVs en backend y materializa `usage/{uid}` para las reglas.
  /// Si Functions aún no están desplegadas, relanza el error al llamador.
  Future<ResumeUsageSnapshot> syncResumeUsage() async {
    final token = await AuthService.instance.getIdToken();
    final res = await http
        .post(
          _endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = decoded['error'];
      final message = err is Map
          ? (err['message'] as String? ?? 'Error al sincronizar uso')
          : (decoded['message'] as String? ??
                'Error al sincronizar uso (${res.statusCode})');
      throw Exception(message);
    }

    final count = (decoded['resumeCount'] as num?)?.toInt() ?? 0;
    final isPro = decoded['isPro'] == true;
    final canCreate =
        decoded['canCreate'] as bool? ??
        PlanLimits.canCreateResume(currentCount: count, isPro: isPro);

    return ResumeUsageSnapshot(
      resumeCount: count,
      isPro: isPro,
      canCreate: canCreate,
    );
  }
}
