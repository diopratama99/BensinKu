import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native Google Sign-In → Supabase.
///
/// Flow (no OAuth redirect, works with self-hosted Supabase over HTTPS):
///   1. `google_sign_in` shows the native account picker on-device.
///   2. We get an `idToken` (+ `accessToken`) issued by Google.
///   3. We hand the token to Supabase via `signInWithIdToken`. Supabase
///      verifies it against the configured Google client IDs and creates
///      or signs into the matching user.
///
/// Config (set once at app bootstrap from [AppConfig]):
///   - [webClientId]  → Google "Web" client id, passed as `serverClientId`.
///                      This is the audience the Supabase server checks.
///   - [iosClientId]  → Google "iOS" client id, only needed on iOS.
class GoogleAuthService {
  GoogleAuthService._();

  /// Populated at bootstrap (see main.dart). Without [webClientId] the
  /// native sign-in can't request an id token usable by Supabase.
  static String? webClientId;
  static String? iosClientId;

  static bool get isConfigured =>
      webClientId != null && webClientId!.trim().isNotEmpty;

  /// Thrown for user-facing failures so the UI can show a friendly message.
  /// `cancelled` is true when the user simply dismissed the picker — the UI
  /// should stay silent in that case.
  static Future<AuthResponse?> signIn() async {
    if (!isConfigured) {
      throw const GoogleAuthException(
        'Login Google belum dikonfigurasi.',
      );
    }

    final googleSignIn = GoogleSignIn(
      // On iOS the per-app client id is required; on Android it's resolved
      // automatically from the package name + SHA-1 registered in Google
      // Cloud, so we leave clientId null there.
      clientId: (!kIsWeb && Platform.isIOS) ? iosClientId : null,
      // serverClientId = the Web client id. Required so Google issues an
      // id token whose audience Supabase will accept.
      serverClientId: webClientId,
      scopes: const ['email', 'profile'],
    );

    final GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
    } catch (e) {
      throw GoogleAuthException('Gagal membuka Google: $e');
    }

    // User dismissed the picker.
    if (account == null) {
      return null;
    }

    final GoogleSignInAuthentication auth;
    try {
      auth = await account.authentication;
    } catch (e) {
      throw GoogleAuthException('Gagal mengambil token Google: $e');
    }

    final idToken = auth.idToken;
    final accessToken = auth.accessToken;
    if (idToken == null) {
      throw const GoogleAuthException(
        'Token Google tidak lengkap (idToken kosong). '
        'Cek konfigurasi client ID.',
      );
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return res;
    } on AuthException catch (e) {
      throw GoogleAuthException(e.message);
    } catch (e) {
      throw GoogleAuthException('Gagal masuk ke server: $e');
    }
  }

  /// Sign out of the Google account too, so the next sign-in shows the
  /// picker again instead of silently reusing the last account.
  static Future<void> signOutGoogle() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Non-fatal.
    }
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
