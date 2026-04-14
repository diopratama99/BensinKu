import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alur lupa password 3 tahap:
/// 1. Input email → kirim OTP code
/// 2. Input kode OTP 6 digit
/// 3. Input password baru → selesai
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { email, otp, newPassword }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  _Step _step = _Step.email;

  // Controllers
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

  // ── Step 1: kirim OTP ke email ─────────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email wajib diisi');
      return;
    }
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

  // ── Step 2: verifikasi OTP ──────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Kode harus 6 digit');
      return;
    }
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
      setState(() => _error = 'Kode salah atau kadaluarsa: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 3: update password baru ───────────────────────────────────────
  Future<void> _updatePassword() async {
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (newPass.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Konfirmasi password tidak sesuai');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (mounted) {
        _showSuccessDialog();
      }
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: CircleAvatar(
          radius: 28,
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.check_rounded,
            size: 30,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text(
          'Password Berhasil Diubah!',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Silakan masuk dengan password baru kamu.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // kembali ke login
            },
            child: const Text('Kembali ke Login'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
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
                  // ── Header ───────────────────────────────────────
                  _StepHeader(
                    step: _step,
                    email: _submittedEmail,
                    cs: cs,
                  ),

                  const SizedBox(height: 28),

                  // ── Progress dots ──────────────────────────────────
                  _StepDots(currentStep: _step, cs: cs),

                  const SizedBox(height: 28),

                  // ── Form card ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.07),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildStepContent(cs),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(ColorScheme cs) {
    switch (_step) {
      case _Step.email:
        return _buildEmailStep(cs);
      case _Step.otp:
        return _buildOtpStep(cs);
      case _Step.newPassword:
        return _buildNewPasswordStep(cs);
    }
  }

  // ── Email Step ──────────────────────────────────────────────────────────
  Widget _buildEmailStep(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _busy ? null : _sendOtp(),
          decoration: InputDecoration(
            labelText: 'Alamat Email',
            hintText: 'contoh@email.com',
            prefixIcon: Icon(Icons.alternate_email_rounded,
                color: cs.primary),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(error: _error!, cs: cs),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _sendOtp,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kirim Kode Verifikasi',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }

  // ── OTP Step ────────────────────────────────────────────────────────────
  Widget _buildOtpStep(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          onSubmitted: (_) => _busy ? null : _verifyOtp(),
          decoration: InputDecoration(
            labelText: 'Kode 6 Digit',
            hintText: '000000',
            hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                letterSpacing: 10),
            counterText: '',
            prefixIcon:
                Icon(Icons.pin_rounded, color: cs.primary),
          ),
        ),
        const SizedBox(height: 8),
        // Resend button
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : _sendOtp,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Kirim ulang kode'),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorBox(error: _error!, cs: cs),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verifyOtp,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verifikasi Kode',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }

  // ── New Password Step ────────────────────────────────────────────────────
  Widget _buildNewPasswordStep(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password Baru',
            hintText: 'Minimal 8 karakter',
            prefixIcon: Icon(Icons.lock_rounded, color: cs.primary),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureNew = !_obscureNew),
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _updatePassword(),
          decoration: InputDecoration(
            labelText: 'Konfirmasi Password',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: cs.primary),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(error: _error!, cs: cs),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _updatePassword,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan Password Baru',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.email,
    required this.cs,
  });

  final _Step step;
  final String? email;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (step) {
      _Step.email => (
          Icons.mark_email_unread_rounded,
          'Reset Password',
          'Masukkan email akun kamu, kami akan mengirimkan kode verifikasi.',
        ),
      _Step.otp => (
          Icons.pin_rounded,
          'Masukkan Kode',
          'Kode 6 digit sudah dikirim ke\n${email ?? ''}',
        ),
      _Step.newPassword => (
          Icons.lock_reset_rounded,
          'Buat Password Baru',
          'Buat password baru yang kuat dan mudah diingat.',
        ),
    };

    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.secondary],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentStep, required this.cs});

  final _Step currentStep;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final steps = _Step.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.map((s) {
        final isActive = s.index <= currentStep.index;
        final isCurrent = s == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isCurrent ? 24 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, required this.cs});

  final String error;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style:
                  TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
