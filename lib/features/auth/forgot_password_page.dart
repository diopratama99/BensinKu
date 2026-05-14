import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';

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
          'PASSWORD DIUBAH',
          style: AppEditorial.mono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        content: Text(
          'Silakan masuk dengan password baru.',
          style: AppEditorial.sans(fontSize: 13),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('KEMBALI KE LOGIN'),
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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
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
                      Text('STEP ${_step.index + 1}/3',
                          style: AppEditorial.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.butterDeep,
                            letterSpacing: 0.6,
                          )),
                      const SizedBox(width: 10),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: AppEditorial.butter,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text('RESET PASSWORD',
                          style: AppEditorial.eyebrow()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _StepHeader(step: _step, email: _submittedEmail),
                  const SizedBox(height: 18),
                  _StepDots(currentStep: _step),
                  const SizedBox(height: 28),
                  Container(height: 1, color: AppEditorial.ink),
                  const SizedBox(height: 24),
                  _buildStepContent(),
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
          style: AppEditorial.mono(
              fontSize: 15, fontWeight: FontWeight.w500),
          onSubmitted: (_) => _busy ? null : _sendOtp(),
          decoration: const InputDecoration(
            labelText: 'EMAIL',
            hintText: 'contoh@email.com',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _sendOtp,
          child: _busy
              ? _btnSpinner()
              : const Text('KIRIM KODE VERIFIKASI →'),
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
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          onSubmitted: (_) => _busy ? null : _verifyOtp(),
          decoration: const InputDecoration(
            labelText: 'KODE 6 DIGIT',
            hintText: '------',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : _sendOtp,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('KIRIM ULANG KODE'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verifyOtp,
          child: _busy ? _btnSpinner() : const Text('VERIFIKASI KODE →'),
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
          style: AppEditorial.mono(
              fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: 'PASSWORD BARU',
            hintText: 'Min. 8 karakter',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppEditorial.inkSoft,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          style: AppEditorial.mono(
              fontSize: 15, fontWeight: FontWeight.w500),
          onSubmitted: (_) => _busy ? null : _updatePassword(),
          decoration: InputDecoration(
            labelText: 'KONFIRMASI PASSWORD',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppEditorial.inkSoft,
                size: 18,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _updatePassword,
          child: _busy
              ? _btnSpinner()
              : const Text('SIMPAN PASSWORD BARU →'),
        ),
      ],
    );
  }

  Widget _btnSpinner() => const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppEditorial.canvas,
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
          'Lupa password.',
          'Masukkan email akun, kami akan kirim kode verifikasi.',
        ),
      _Step.otp => (
          'Cek email.',
          'Kode 6 digit dikirim ke ${email ?? ''}.',
        ),
      _Step.newPassword => (
          'Buat password baru.',
          'Password kuat dan mudah diingat.',
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppEditorial.mono(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppEditorial.sans(
            fontSize: 13,
            color: AppEditorial.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentStep});
  final _Step currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_Step.values.length, (i) {
        final isActive = i <= currentStep.index;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
            height: 2,
            color: isActive ? AppEditorial.ink : AppEditorial.hairline,
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
