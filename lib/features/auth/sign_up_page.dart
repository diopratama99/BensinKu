import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
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

    if (name.isEmpty) return setState(() => _error = 'Nama wajib diisi');
    if (email.isEmpty) return setState(() => _error = 'Email wajib diisi');
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      return setState(() => _error = 'Format email tidak valid');
    }
    if (password.length < 8) {
      return setState(() => _error = 'Password minimal 8 karakter');
    }
    if (password != confirm) {
      return setState(() => _error = 'Konfirmasi password tidak cocok');
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

      if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
        setState(() => _error = 'Email sudah terdaftar.');
        return;
      }

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
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('BENSINKU',
                          style: AppEditorial.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          )),
                      const SizedBox(width: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppEditorial.butter,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('VOL.02 · DAFTAR',
                          style: AppEditorial.eyebrow()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Buat akun baru.',
                    style: AppEditorial.mono(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Isi form, lalu cek email untuk verifikasi.',
                    style: AppEditorial.sans(
                      fontSize: 13,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(height: 1, color: AppEditorial.ink),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    style: AppEditorial.mono(
                        fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: 'NAMA LENGKAP',
                      hintText: 'John Doe',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    style: AppEditorial.mono(
                        fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: 'EMAIL',
                      hintText: 'contoh@email.com',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePass,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    style: AppEditorial.mono(
                        fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'PASSWORD',
                      hintText: 'Min. 8 karakter',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppEditorial.inkSoft,
                          size: 18,
                        ),
                        onPressed: () => setState(
                            () => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    style: AppEditorial.mono(
                        fontSize: 15, fontWeight: FontWeight.w500),
                    onSubmitted: (_) => _busy ? null : _signUp(),
                    decoration: InputDecoration(
                      labelText: 'KONFIRMASI PASSWORD',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppEditorial.inkSoft,
                          size: 18,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBox(message: _error!),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _signUp,
                    child: _busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppEditorial.canvas,
                            ),
                          )
                        : const Text('DAFTAR & VERIFIKASI →'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('SUDAH PUNYA AKUN? MASUK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppEditorial.rust, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppEditorial.rust, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 12.5,
                color: AppEditorial.rust,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
