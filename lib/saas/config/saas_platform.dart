import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// En Windows/Linux el SDK nativo de Firebase Auth/Firestore es inestable (gRPC).
/// Usamos Identity Toolkit + Firestore REST y no tocamos el plugin nativo.
bool get saasUseRestBackend {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}
