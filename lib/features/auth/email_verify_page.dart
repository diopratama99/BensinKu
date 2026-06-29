import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import 'sign_in_page.dart';

class EmailVerifyPage extends StatefulWidget {
  const EmailVerifyPage({super.key, required this.email});

  final String email;

  @override
  State<EmailVerifyPage> createState() => _EmailVerifyPageState();
}

class _EmailVerifyPageState extends State<EmailVerifyPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
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
      setState(() => _error = 'Masukkan 6 digit kode');
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
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((r) => r.isFirst);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.contains('expired') ||
                  e.message.contains('invalid')
              ? 'Kode salah/kedaluwarsa.'
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
        setState(() => _resendMsg = 'Kode baru dikirim.');
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
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandMark(),
                  const SizedBox(height: 40),

                  // Mail icon in rounded brandTint box
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppEditorial.brandTint,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rCard),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.envelopeSimple,
                      color: AppEditorial.brandDeep,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Cek inbox',
                    style: AppEditorial.heading(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Masukkan kode 6 digit yang dikirim ke:',
                    style: AppEditorial.sans(
                      fontSize: 13.5,
                      color: AppEditorial.inkSoft,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: AppEditorial.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.brandDeep,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // OTP card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppEditorial.cream,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rCard),
                      boxShadow: AppEditorial.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) {
                            return _OtpBox(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              onChanged: (v) => _onDigitChanged(i, v),
                              onKey: (e) => _onKeyEvent(i, e),
                              autoFocus: i == 0,
                              allowPaste: i == 0,
                            );
                          }),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          _ErrorBox(message: _error!),
                        ],
                        if (_resendMsg != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              _resendMsg!,
                              style: AppEditorial.sans(
                                fontSize: 12.5,
                                color: _resendMsg!.startsWith('Gagal')
                                    ? AppEditorial.rust
                                    : AppEditorial.sage,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _verifying ? null : _verifyOtp,
                          child: _verifying
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                )
                              : const Text('Verifikasi'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _resending ? null : _resendCode,
                      icon: _resending
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
                      label: const Text('Kirim ulang kode'),
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context)
                          .popUntil((r) => r.isFirst),
                      icon:
                          const Icon(PhosphorIconsRegular.arrowLeft, size: 16),
                      label: const Text('Kembali ke masuk'),
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKey,
    this.autoFocus = false,
    this.allowPaste = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKey;
  final bool autoFocus;
  final bool allowPaste;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 58,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: onKey,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: autoFocus,
          maxLength: allowPaste ? 6 : 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppEditorial.mono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: AppEditorial.canvasSoft,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppEditorial.rButton),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppEditorial.rButton),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppEditorial.rButton),
              borderSide:
                  const BorderSide(color: AppEditorial.ink, width: 1.6),
            ),
          ),
          onChanged: onChanged,
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
