import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../services/refuel_parser_service.dart';

/// Receipt scan — looks like a scanning console.
class ReceiptProcessingSheet extends StatefulWidget {
  const ReceiptProcessingSheet({super.key, required this.image});

  final XFile image;

  @override
  State<ReceiptProcessingSheet> createState() =>
      _ReceiptProcessingSheetState();
}

class _ReceiptProcessingSheetState extends State<ReceiptProcessingSheet> {
  final _parser = RefuelParserService();

  bool _processing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final bytes = await widget.image.readAsBytes();
      final mime = _guessMime(widget.image.path);
      final parsed = await _parser.parseReceiptBytes(bytes, mime);
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

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.7,
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
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _processing
                        ? AppEditorial.butterDeep
                        : (_error != null
                            ? AppEditorial.rust
                            : AppEditorial.sage),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _processing
                      ? 'SCAN · PROCESSING'
                      : (_error != null ? 'ERROR' : 'OK'),
                  style: AppEditorial.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                if (!_processing)
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
              _processing
                  ? 'AI baca strukmu, sebentar...'
                  : (_error != null
                      ? 'gagal memindai struk.'
                      : 'siap.'),
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppEditorial.ink),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppEditorial.ink, width: 1.5),
                    ),
                    child: Image.file(
                      File(widget.image.path),
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_processing) ...[
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: AppEditorial.ink,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'mengirim ke AI vision...',
                      style: AppEditorial.mono(
                        fontSize: 11,
                        color: AppEditorial.inkSoft,
                      ),
                    ),
                  ] else if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppEditorial.rust, width: 1),
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppEditorial.rust, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppEditorial.sans(
                                fontSize: 13,
                                color: AppEditorial.rust,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_processing && _error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('TUTUP'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _start,
                      child: const Text('COBA LAGI ↺'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

typedef ReceiptParsed = ParsedRefuel;
