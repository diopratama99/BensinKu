import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';

/// Global avatar cache-bust token. Bumping this forces every [UserAvatar]
/// in the tree to re-download the photo — call [UserAvatar.bumpCacheBust]
/// right after a successful upload so the new image shows immediately.
final ValueNotifier<int> avatarRevision =
    ValueNotifier<int>(DateTime.now().millisecondsSinceEpoch);

/// Renders the signed-in user's avatar from Supabase Storage, with a
/// monogram fallback (first letters of the display name) when no photo
/// exists or the network load fails.
///
/// Data sources (no extra tables queried — everything lives in the auth
/// layer + a public storage bucket shared with the other apps):
///   - Display name  → `auth.currentUser.userMetadata['name']`
///   - Avatar file   → bucket `avatars`, path `avatars/<userId>.jpg`
///   - Public URL    → `storage.from('avatars').getPublicUrl(...)`
///
/// Cache-busting: a query param `?v=<rev>` is appended where `<rev>` comes
/// from [avatarRevision]. It stays stable across rebuilds (so the image
/// caches within a session) but can be bumped after an upload to refresh
/// every instance at once.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.size = 40,
    this.shape = BoxShape.rectangle,
    this.borderRadius = AppEditorial.rTiny,
    this.borderColor = AppEditorial.ink,
    this.borderWidth = 1.5,
    this.background = AppEditorial.butter,
    this.monogramFontSize,
  });

  /// Width & height of the (square) avatar.
  final double size;

  /// `rectangle` (default, editorial box) or `circle`.
  final BoxShape shape;

  /// Corner radius when [shape] is `rectangle`.
  final double borderRadius;

  final Color borderColor;
  final double borderWidth;
  final Color background;

  /// Monogram text size. Defaults to ~38% of [size].
  final double? monogramFontSize;

  /// Force a re-fetch of every avatar (call after a successful upload).
  static void bumpCacheBust() {
    avatarRevision.value = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: avatarRevision,
      builder: (context, revision, _) => _build(context, revision),
    );
  }

  Widget _build(BuildContext context, int revision) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = _displayName(user);
    final monogram = _initials(name);

    final fontSize = monogramFontSize ?? size * 0.38;
    final radius = shape == BoxShape.circle ? size / 2 : borderRadius;
    final isRect = shape == BoxShape.rectangle;

    // Background fill (sits behind the image / monogram).
    final backgroundDecoration = BoxDecoration(
      color: background,
      shape: shape,
      borderRadius: isRect ? BorderRadius.circular(radius) : null,
    );

    // Border drawn on top so it frames the photo cleanly.
    final foregroundBorder = BoxDecoration(
      shape: shape,
      border: Border.all(color: borderColor, width: borderWidth),
      borderRadius: isRect ? BorderRadius.circular(radius) : null,
    );

    final monogramChild = Text(
      monogram,
      style: AppEditorial.heading(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: AppEditorial.ink,
      ),
    );

    final url = _avatarUrl(user, revision);

    Widget content;
    if (url == null) {
      content = Center(child: monogramChild);
    } else {
      content = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        // While downloading: show the monogram so there's no blank flash.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(child: monogramChild);
        },
        // 404 (no avatar yet) or any network error → monogram.
        errorBuilder: (context, error, stack) => Center(child: monogramChild),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: backgroundDecoration,
      foregroundDecoration: foregroundBorder,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  /// Public storage URL for the user's avatar, or null if signed out.
  ///
  /// Cache-bust priority:
  ///   1. `user_metadata.avatar_updated_at` — a SHARED token written by
  ///      whichever app last changed the photo. Because it lives in the
  ///      auth layer, every app sharing this Supabase instance reads the
  ///      same value, so a change in one app propagates to the others.
  ///   2. `revision` — local fallback (bumped on resume / pull-to-refresh)
  ///      used when no shared token exists yet.
  String? _avatarUrl(User? user, int revision) {
    if (user == null) return null;
    final base = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl('avatars/${user.id}.jpg');
    final shared = user.userMetadata?['avatar_updated_at'];
    final token = shared is int
        ? shared
        : (shared is String ? (int.tryParse(shared) ?? revision) : revision);
    return '$base?v=$token';
  }

  static String _displayName(User? user) {
    final raw = user?.userMetadata?['name'];
    final name = raw is String ? raw.trim() : '';
    if (name.isNotEmpty) return name;
    final email = user?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (parts.isEmpty) return '?';
    return parts
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
  }
}
