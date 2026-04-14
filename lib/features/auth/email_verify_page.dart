import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after sign-up. User enters the 6-digit OTP from their email.
class EmailVerifyPage extends StatefulWidget {
  const EmailVerifyPage({super.key, required this.email});

  final String email;

  @override
  State<EmailVerifyPage> createState() => _EmailVerifyPageState();
}

class _EmailVerifyPageState extends State<EmailVerifyPage> {
  // 6 separate controllers for each digit box
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _resendMsg;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Paste support: spread digits across boxes
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextFocus = digits.length < 6 ? digits.length : 5;
      _focusNodes[nextFocus].requestFocus();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-verify when all 6 filled
    if (_otp.length == 6) _verifyOtp();
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otp;
    if (code.length < 6) {
      setState(() => _error = 'Masukkan 6 digit kode verifikasi');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );
      // Pop semua route ke root agar _AuthGate (StreamBuilder) bisa rebuild
      // ke WelcomePage/HomeShell sesuai kondisi auth yang baru.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.contains('expired') || e.message.contains('invalid')
              ? 'Kode salah atau sudah kedaluwarsa. Kirim ulang kode.'
              : e.message;
          for (final c in _controllers) {
            c.clear();
          }
        });
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _resending = true;
      _resendMsg = null;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        setState(() => _resendMsg = 'Kode baru dikirim ke ${widget.email}');
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _resendMsg = 'Gagal: ${e.message}');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Icon
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.lock_open_rounded,
                        color: cs.onPrimary, size: 38),
                  ),
                  const SizedBox(height: 22),

                  Text(
                    'Masukkan Kode Verifikasi',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kode 6 digit dikirim ke:',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      widget.email,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── 6-digit OTP boxes ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5),
                        child: SizedBox(
                          width: 46,
                          height: 56,
                          child: KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (e) => _onKeyEvent(i, e),
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: i == 0 ? 6 : 1, // allow paste on first
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: _controllers[i].text.isNotEmpty
                                    ? cs.primaryContainer
                                    : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: cs.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: cs.primary, width: 2),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) => _onDigitChanged(i, v),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // Error
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style:
                                    TextStyle(color: cs.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _verifying ? null : _verifyOtp,
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _verifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(_verifying
                          ? 'Memverifikasi...'
                          : 'Verifikasi'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resend
                  if (_resendMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _resendMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _resendMsg!.startsWith('Gagal')
                              ? cs.error
                              : cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  TextButton.icon(
                    onPressed: _resending ? null : _resendCode,
                    icon: _resending
                        ? const SizedBox(
                            height: 14, width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Kirim ulang kode'),
                  ),

                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Kembali ke Login'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
