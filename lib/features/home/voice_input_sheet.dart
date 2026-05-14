import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../services/refuel_parser_service.dart';

/// Voice input — looks like a recording console.
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppEditorial.ink, width: 1),
          left: BorderSide(color: AppEditorial.ink, width: 1),
          right: BorderSide(color: AppEditorial.ink, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                color: AppEditorial.hairline,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Recording status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _listening
                        ? AppEditorial.rust
                        : AppEditorial.inkMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _listening ? 'REC · MENDENGAR' : 'VOICE INPUT',
                  style: AppEditorial.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _listening
                        ? AppEditorial.rust
                        : AppEditorial.ink,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppEditorial.ink, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'contoh: "isi pertamax 50 ribu di motor"',
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppEditorial.ink),
            const SizedBox(height: 16),
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
        Text(
          _listening ? 'TRANSKRIP (LIVE)' : 'TRANSKRIP',
          style: AppEditorial.eyebrow(),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              _transcript.isEmpty
                  ? (_listening
                      ? 'mulai bicara sekarang...'
                      : 'tap mic di bawah untuk mulai.')
                  : _transcript,
              style: AppEditorial.mono(
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
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _ErrorBox(message: _error!),
        ],
        if (_processing) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppEditorial.ink,
                ),
              ),
              const SizedBox(width: 10),
              Text('AI memproses...',
                  style: AppEditorial.sans(
                    fontSize: 13,
                    color: AppEditorial.inkSoft,
                  )),
            ],
          ),
        ],
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
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          color: disabled
              ? AppEditorial.cream
              : (_listening ? AppEditorial.rust : AppEditorial.ink),
          border: Border.all(color: AppEditorial.ink, width: 1.5),
          borderRadius: BorderRadius.circular(AppEditorial.rButton),
        ),
        child: Icon(
          _listening ? Icons.stop_rounded : Icons.mic_rounded,
          color: disabled
              ? AppEditorial.inkMuted
              : AppEditorial.canvas,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppEditorial.rust, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppEditorial.rust, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 13,
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
