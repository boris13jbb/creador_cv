import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../config/plan_limits.dart';
import '../config/saas_config.dart';
import 'auth_service.dart';

/// Resultado de [CreateResumeService.create].
class CreateResumeResult {
  const CreateResumeResult({
    required this.resumeId,
    required this.created,
    required this.resumeCount,
    required this.isPro,
    required this.idempotentReplay,
  });

  final String resumeId;
  final bool created;
  final int resumeCount;
  final bool isPro;
  final bool idempotentReplay;
}

/// Cliente HTTP de creación atómica (`createResume` Cloud Function).
class CreateResumeService {
  CreateResumeService._();
  static final instance = CreateResumeService._();

  Uri get _endpoint {
    final base = SaasConfig.billingFunctionsBaseUrl.replaceAll(
      RegExp(r'/$'),
      '',
    );
    return Uri.parse('$base/createResume');
  }

  /// Crea el CV en servidor. [resumeId] e [idempotencyKey] evitan duplicados.
  Future<CreateResumeResult> create({
    required String resumeId,
    required Map<String, dynamic> resume,
    String? idempotencyKey,
  }) async {
    final token = await AuthService.instance.getIdToken();
    final body = <String, dynamic>{
      'resumeId': resumeId,
      'resume': resume,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotencyKey': idempotencyKey,
    };

    late final http.Response res;
    try {
      res = await http
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw NetworkAppException(PlanLimits.usageSyncRequiredMessage());
    }

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = decoded['error'];
      final code = err is Map ? err['code'] as String? : null;
      final message = err is Map
          ? (err['message'] as String? ?? 'No se pudo crear el CV')
          : (decoded['message'] as String? ??
                'No se pudo crear el CV (${res.statusCode})');
      if (code == 'resource-exhausted' || res.statusCode == 429) {
        throw AppException(
          PlanLimits.limitReachedMessage(isPro: false),
          code: 'resource-exhausted',
        );
      }
      if (code == 'unauthenticated' || res.statusCode == 401) {
        throw AuthAppException(message);
      }
      if (res.statusCode >= 500) {
        throw NetworkAppException(message);
      }
      throw AppException(message, code: code);
    }

    return CreateResumeResult(
      resumeId: decoded['resumeId'] as String? ?? resumeId,
      created: decoded['created'] == true,
      resumeCount: (decoded['resumeCount'] as num?)?.toInt() ?? 0,
      isPro: decoded['isPro'] == true,
      idempotentReplay: decoded['idempotentReplay'] == true,
    );
  }
}
