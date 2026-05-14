import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';

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
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('STEP 03 · VERIFIKASI',
                          style: AppEditorial.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.butterDeep,
                            letterSpacing: 0.6,
                          )),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Text(
                    'Cek inbox.',
                    style: AppEditorial.mono(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Masukkan kode 6 digit yang dikirim ke:',
                    style: AppEditorial.sans(
                      fontSize: 13,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.email,
                    style: AppEditorial.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.butterDeep,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(height: 1, color: AppEditorial.ink),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    const SizedBox(height: 16),
                    _ErrorBox(message: _error!),
                  ],
                  if (_resendMsg != null) ...[
                    const SizedBox(height: 10),
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _verifying ? null : _verifyOtp,
                    child: _verifying
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppEditorial.canvas,
                            ),
                          )
                        : const Text('VERIFIKASI →'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _resending ? null : _resendCode,
                      icon: _resending
                          ? const SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('KIRIM ULANG KODE'),
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context)
                          .popUntil((r) => r.isFirst),
                      icon:
                          const Icon(Icons.arrow_back_rounded, size: 14),
                      label: const Text('KEMBALI KE LOGIN'),
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
      width: 44,
      height: 56,
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
          decoration: const InputDecoration(
            counterText: '',
            isDense: true,
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppEditorial.hairline, width: 1),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppEditorial.hairline, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppEditorial.ink, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
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
