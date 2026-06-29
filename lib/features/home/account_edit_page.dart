import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../widgets/user_avatar.dart';

/// Editable account page — display name, avatar photo, and password.
///
/// All writes hit the auth layer + the shared `avatars` storage bucket
/// (same model as the other apps sharing this Supabase instance):
///   - Name      → `auth.updateUser(UserAttributes(data: {'name': ...}))`
///   - Avatar    → upload to bucket `avatars`, path `avatars/<userId>.jpg`
///   - Password  → `auth.updateUser(UserAttributes(password: ...))`
class AccountEditPage extends StatefulWidget {
  const AccountEditPage({super.key});

  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  bool _uploadingAvatar = false;

  String get _name {
    final raw =
        Supabase.instance.client.auth.currentUser?.userMetadata?['name'];
    return raw is String ? raw.trim() : '';
  }

  String get _email => Supabase.instance.client.auth.currentUser?.email ?? '';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Avatar upload ──────────────────────────────────────────────────
  Future<void> _changeAvatar() async {
    final source = await _pickSource();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('Belum login.');

      final bytes = await File(picked.path).readAsBytes();
      // Path matches the shared convention: avatars/<userId>.jpg, always
      // overwritten (upsert) so re-upload replaces the old photo.
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            'avatars/${user.id}.jpg',
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
              // Short cache so any client re-requesting the same URL gets
              // the fresh object quickly instead of a long-lived stale copy.
              cacheControl: '60',
            ),
          );

      // Write a SHARED version token into auth user_metadata. Every app
      // sharing this Supabase instance can read `avatar_updated_at` and use
      // it as the cache-bust token, so a change here propagates to the
      // others (once they read fresh metadata) — not just within this app.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?Supabase.instance.client.auth.currentUser?.userMetadata,
            'avatar_updated_at': stamp,
          },
        ),
      );

      // Force every UserAvatar to re-fetch with a fresh cache-bust token.
      UserAvatar.bumpCacheBust();
      _toast('Foto profil diperbarui');
    } catch (e) {
      _toast('Gagal upload foto: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppEditorial.hairline,
                    borderRadius: BorderRadius.circular(AppEditorial.rPill),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Foto profil',
                  style: AppEditorial.heading(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 12),
              _SourceTile(
                icon: PhosphorIconsRegular.camera,
                label: 'Ambil foto',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: PhosphorIconsRegular.image,
                label: 'Pilih dari galeri',
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Name edit ──────────────────────────────────────────────────────
  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nama tampilan',
            style: AppEditorial.heading(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            )),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: AppEditorial.sans(fontSize: 15),
          decoration: const InputDecoration(hintText: 'Nama kamu'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == _name) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?Supabase.instance.client.auth.currentUser?.userMetadata,
            'name': newName,
          },
        ),
      );
      if (mounted) setState(() {});
      _toast('Nama diperbarui');
    } catch (e) {
      _toast('Gagal simpan nama: $e');
    }
  }

  // ── Password change ────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _PasswordChangePage()),
    );
    if (result == true) _toast('Password diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Akun'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Avatar with camera badge ──
          Center(
            child: GestureDetector(
              onTap: _uploadingAvatar ? null : _changeAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const UserAvatar(
                    size: 104,
                    shape: BoxShape.circle,
                    monogramFontSize: 40,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: AppEditorial.brand,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppEditorial.canvas, width: 2),
                      ),
                      child: _uploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppEditorial.ink,
                              ),
                            )
                          : const Icon(PhosphorIconsRegular.camera,
                              size: 17, color: AppEditorial.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Ketuk foto untuk mengganti',
              style: AppEditorial.sans(
                fontSize: 12.5,
                color: AppEditorial.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // §01 Identity
          const EditorialSectionHeader(label: 'Identitas'),
          const SizedBox(height: 12),
          EditorialCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: [
                _FieldRow(
                  label: 'Nama',
                  value: _name.isEmpty ? 'Belum diatur' : _name,
                  onTap: _editName,
                  trailing: const Icon(PhosphorIconsRegular.caretRight,
                      size: 20, color: AppEditorial.inkMuted),
                ),
                _FieldRow(
                  label: 'Email',
                  value: _email.isEmpty ? '—' : _email,
                  subtitle: 'Hubungi support untuk mengubah email.',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // §02 Security
          const EditorialSectionHeader(label: 'Keamanan'),
          const SizedBox(height: 12),
          EditorialCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: _FieldRow(
              label: 'Password',
              value: '••••••••',
              onTap: _changePassword,
              isLast: true,
              trailing: const Icon(PhosphorIconsRegular.caretRight,
                  size: 20, color: AppEditorial.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppEditorial.rButton),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rButton),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppEditorial.brandTint,
                  borderRadius: BorderRadius.circular(AppEditorial.rTiny),
                ),
                child: Icon(icon,
                    size: 20, color: AppEditorial.brandDeep),
              ),
              const SizedBox(width: 14),
              Text(label,
                  style: AppEditorial.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isLast = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : AppEditorial.hairlineSoft,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppEditorial.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppEditorial.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppEditorial.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppEditorial.sans(
                      fontSize: 11.5,
                      color: AppEditorial.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      child: row,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password change page
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordChangePage extends StatefulWidget {
  const _PasswordChangePage();

  @override
  State<_PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<_PasswordChangePage> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Konfirmasi password tidak cocok.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ganti password'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Masukkan password baru. Minimal 6 karakter.',
            style: AppEditorial.sans(
              fontSize: 13.5,
              color: AppEditorial.inkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            style: AppEditorial.sans(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Password baru',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? PhosphorIconsRegular.eyeSlash
                      : PhosphorIconsRegular.eye,
                  color: AppEditorial.inkSoft,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            style: AppEditorial.sans(fontSize: 15),
            onSubmitted: (_) => _saving ? null : _save(),
            decoration: const InputDecoration(
              labelText: 'Konfirmasi password',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppEditorial.rustSoft,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.warningCircle,
                      color: AppEditorial.rust, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppEditorial.sans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppEditorial.rust,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFFFFF),
                    ),
                  )
                : const Text('Simpan password'),
          ),
        ],
      ),
    );
  }
}
