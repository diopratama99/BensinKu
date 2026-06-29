import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import 'sign_in_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { email, otp, newPassword }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  _Step _step = _Step.email;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _busy = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _submittedEmail;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return setState(() => _error = 'Email wajib diisi');

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      _submittedEmail = email;
      if (mounted) setState(() => _step = _Step.otp);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) return setState(() => _error = 'Kode 6 digit');

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _submittedEmail!,
        token: otp,
        type: OtpType.recovery,
      );
      if (mounted) setState(() => _step = _Step.newPassword);
    } on AuthException catch (e) {
      setState(() => _error = 'Kode salah/kadaluarsa: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (newPass.length < 8) {
      return setState(() => _error = 'Password minimal 8 karakter');
    }
    if (newPass != confirm) {
      return setState(() => _error = 'Konfirmasi tidak sesuai');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (mounted) _showSuccessDialog();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Password diubah',
          style: AppEditorial.heading(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Silakan masuk dengan password baru.',
          style: AppEditorial.sans(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Kembali ke masuk'),
          ),
        ],
      ),
    );
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandMark(),
                  const SizedBox(height: 28),
                  _StepHeader(step: _step, email: _submittedEmail),
                  const SizedBox(height: 18),
                  _StepProgress(currentStep: _step),
                  const SizedBox(height: 22),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppEditorial.cream,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rCard),
                      boxShadow: AppEditorial.softShadow,
                    ),
                    child: _buildStepContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _Step.email:
        return _buildEmailStep();
      case _Step.otp:
        return _buildOtpStep();
      case _Step.newPassword:
        return _buildNewPasswordStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _busy ? null : _sendOtp(),
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'contoh@email.com',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _sendOtp,
          child: _busy
              ? _btnSpinner()
              : const Text('Kirim kode verifikasi'),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppEditorial.mono(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          onSubmitted: (_) => _busy ? null : _verifyOtp(),
          decoration: const InputDecoration(
            labelText: 'Kode 6 digit',
            hintText: '••••••',
            counterText: '',
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : _sendOtp,
            icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
            label: const Text('Kirim ulang kode'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _verifyOtp,
          child: _busy ? _btnSpinner() : const Text('Verifikasi kode'),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password baru',
            hintText: 'Min. 8 karakter',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
              icon: Icon(
                _obscureNew
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
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _updatePassword(),
          decoration: InputDecoration(
            labelText: 'Konfirmasi password',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? PhosphorIconsRegular.eyeSlash
                    : PhosphorIconsRegular.eye,
                color: AppEditorial.inkSoft,
                size: 20,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _updatePassword,
          child: _busy
              ? _btnSpinner()
              : const Text('Simpan password baru'),
        ),
      ],
    );
  }

  Widget _btnSpinner() => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFFFFFFF),
        ),
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.email});
  final _Step step;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (step) {
      _Step.email => (
          'Lupa password',
          'Masukkan email akun, kami akan kirim kode verifikasi.',
        ),
      _Step.otp => (
          'Cek email',
          'Kode 6 digit dikirim ke ${email ?? ''}.',
        ),
      _Step.newPassword => (
          'Buat password baru',
          'Password kuat dan mudah diingat.',
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppEditorial.heading(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppEditorial.sans(
            fontSize: 13.5,
            color: AppEditorial.inkSoft,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep});
  final _Step currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_Step.values.length, (i) {
        final isActive = i <= currentStep.index;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AppEditorial.brand : AppEditorial.hairline,
              borderRadius: BorderRadius.circular(AppEditorial.rPill),
            ),
          ),
        );
      }),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppEditorial.rustSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsRegular.warningCircle,
              color: AppEditorial.rust, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppEditorial.rust,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
