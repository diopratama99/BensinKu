import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/brand_scaffold.dart';
import 'email_verify_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      setState(() => _error = 'Nama wajib diisi');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Email wajib diisi');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _error = 'Format email tidak valid');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (!mounted) return;

      // If identities is empty, email already registered
      if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
        setState(() => _error = 'Email sudah terdaftar. Silakan login.');
        return;
      }

      // Navigate to verification waiting page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmailVerifyPage(email: email),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: BrandBackdrop(
        assetPath: 'assets/illustrations/dashboard_wave.svg',
        topPadding: -30,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Back button ──────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.12),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(Icons.arrow_back_rounded,
                              color: cs.primary, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Form card ────────────────────────────────────────
                    BrandPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.person_add_alt_1_rounded,
                                    color: cs.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Buat Akun Baru',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Isi data di bawah, lalu cek email untuk verifikasi.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 18),

                          // Name
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Nama Lengkap',
                              hintText: 'John Doe',
                              prefixIcon:
                                  Icon(Icons.badge_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'contoh@email.com',
                              prefixIcon:
                                  Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Minimal 8 karakter',
                              prefixIcon: const Icon(Icons.lock_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded),
                                onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Confirm password
                          TextField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _busy ? null : _signUp(),
                            decoration: InputDecoration(
                              labelText: 'Konfirmasi Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Error banner
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: cs.onErrorContainer),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                          color: cs.onErrorContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Submit
                          FilledButton.icon(
                            onPressed: _busy ? null : _signUp,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Icon(Icons.mail_rounded),
                            label: Text(_busy
                                ? 'Mendaftar...'
                                : 'Daftar & Kirim Verifikasi'),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Sudah punya akun? Masuk'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
