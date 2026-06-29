import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../services/refuel_parser_service.dart';

/// Voice input — dictate a refuel and let AI parse it.
class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  final _speech = stt.SpeechToText();
  final _parser = RefuelParserService();

  bool _initializing = true;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _processing = false;
  String _transcript = '';
  String? _error;
  Timer? _autoStop;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final mic = await Permission.microphone.request();
      if (mic.isPermanentlyDenied) {
        setState(() {
          _initializing = false;
          _error = 'Izin mikrofon diblokir.';
        });
        return;
      }
      if (!mic.isGranted) {
        setState(() {
          _initializing = false;
          _error = 'Izin mikrofon ditolak.';
        });
        return;
      }

      final available = await _speech.initialize(
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _error = 'Speech error: ${err.errorMsg}';
            _listening = false;
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _initializing = false;
        _speechAvailable = available;
        if (!available) {
          _error =
              'Speech-to-text tidak tersedia di perangkat ini.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Gagal init: $e';
      });
    }
  }

  Future<void> _toggleListen() async {
    if (_processing) return;
    if (_listening) {
      await _stopListening();
      return;
    }
    if (!_speechAvailable) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _transcript = '';
      _error = null;
      _listening = true;
    });

    await _speech.listen(
      localeId: 'id_ID',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
      },
    );

    _autoStop?.cancel();
    _autoStop = Timer(const Duration(seconds: 12), () {
      if (_listening) _stopListening();
    });
  }

  Future<void> _stopListening() async {
    _autoStop?.cancel();
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    await _submit();
  }

  Future<void> _submit() async {
    final text = _transcript.trim();
    if (text.isEmpty) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final parsed = await _parser.parseVoice(text);
      if (!mounted) return;
      Navigator.of(context).pop(parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.62,
      decoration: const BoxDecoration(
        color: AppEditorial.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input suara',
                        style: AppEditorial.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Contoh: "isi pertamax 50 ribu di motor"',
                        style: AppEditorial.sans(
                          fontSize: 13,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_listening)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppEditorial.rustSoft,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppEditorial.rust,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Mendengar',
                          style: AppEditorial.sans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.rust,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(PhosphorIconsRegular.x,
                      color: AppEditorial.inkSoft, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(child: _buildBody()),
            const SizedBox(height: 16),
            _buildMicButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppEditorial.ink),
      );
    }
    if (_error != null && !_speechAvailable) {
      return _ErrorBox(message: _error!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _listening ? 'Transkrip langsung' : 'Transkrip',
                style: AppEditorial.sans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppEditorial.inkSoft,
                ),
              ),
              if (_listening)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: AspectRatio(
                    aspectRatio: 1080 / 400,
                    child: Image.asset(
                      'assets/illustrations/voice_wave.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                _transcript.isEmpty
                    ? (_listening
                        ? 'Mulai bicara sekarang…'
                        : 'Ketuk mic di bawah untuk mulai.')
                    : _transcript,
                style: AppEditorial.sans(
                  fontSize: 16,
                  fontWeight: _transcript.isEmpty
                      ? FontWeight.w400
                      : FontWeight.w600,
                  color: _transcript.isEmpty
                      ? AppEditorial.inkMuted
                      : AppEditorial.ink,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) _ErrorBox(message: _error!),
                if (_processing) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppEditorial.ink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('AI sedang memproses…',
                          style: AppEditorial.sans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppEditorial.inkSoft,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMicButton() {
    final disabled = _initializing ||
        _processing ||
        (!_speechAvailable && _error != null);

    return GestureDetector(
      onTap: disabled ? null : _toggleListen,
      child: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          color: disabled
              ? AppEditorial.hairline
              : (_listening ? AppEditorial.rust : AppEditorial.ink),
          shape: BoxShape.circle,
          boxShadow: disabled ? null : AppEditorial.softShadow,
        ),
        child: Icon(
          _listening ? PhosphorIconsRegular.stop : PhosphorIconsRegular.microphone,
          color: disabled
              ? AppEditorial.inkMuted
              : const Color(0xFFFFFFFF),
          size: 28,
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
      padding: const EdgeInsets.all(14),
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
              message,
              style: AppEditorial.sans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppEditorial.rust,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef VoiceParsed = ParsedRefuel;
