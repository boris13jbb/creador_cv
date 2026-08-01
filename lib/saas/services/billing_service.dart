import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/saas_config.dart';
import 'auth_service.dart';

/// Cliente de billing contra Cloud Functions HTTP (Checkout + Portal).
/// Compatible con Auth nativo y sesión REST (Bearer ID token).
class BillingService {
  BillingService._();
  static final instance = BillingService._();

  Uri _endpoint(String name) {
    final base = SaasConfig.billingFunctionsBaseUrl.replaceAll(
      RegExp(r'/$'),
      '',
    );
    return Uri.parse('$base/$name');
  }

  Future<Map<String, dynamic>> _post(
    String name, {
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthService.instance.getIdToken();
    final res = await http
        .post(
          _endpoint(name),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body ?? const <String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 45));

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    final err = decoded['error'];
    final message = err is Map
        ? (err['message'] as String? ?? 'Error de billing')
        : (decoded['message'] as String? ??
              'Error de billing (${res.statusCode})');
    throw Exception(message);
  }

  /// Crea Checkout Session y devuelve la URL de Stripe.
  Future<Uri> createCheckoutUrl({String? successUrl, String? cancelUrl}) async {
    final data = await _post(
      'createCheckoutSession',
      body: {
        if (successUrl != null) 'successUrl': successUrl,
        if (cancelUrl != null) 'cancelUrl': cancelUrl,
      },
    );
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Checkout no devolvió URL');
    }
    return Uri.parse(url);
  }

  /// Abre Customer Portal para gestionar suscripción.
  Future<Uri> createPortalUrl({String? returnUrl}) async {
    final data = await _post(
      'createPortalSession',
      body: {if (returnUrl != null) 'returnUrl': returnUrl},
    );
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Portal no devolvió URL');
    }
    return Uri.parse(url);
  }
}
