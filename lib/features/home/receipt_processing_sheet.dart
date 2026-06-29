import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../services/refuel_parser_service.dart';

/// Receipt scan — reads the struk with AI vision.
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

    final Color statusColor = _processing
        ? AppEditorial.brandDeep
        : (_error != null ? AppEditorial.rust : AppEditorial.sage);
    final String statusLabel = _processing
        ? 'Memproses'
        : (_error != null ? 'Gagal' : 'Selesai');

    return Container(
      height: screenH * 0.7,
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
                        'Scan struk',
                        style: AppEditorial.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _processing
                            ? 'AI sedang membaca strukmu…'
                            : (_error != null
                                ? 'Gagal memindai struk.'
                                : 'Struk berhasil dibaca.'),
                        style: AppEditorial.sans(
                          fontSize: 13,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        statusLabel,
                        style: AppEditorial.sans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_processing)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(PhosphorIconsRegular.x,
                          color: AppEditorial.inkSoft, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rCard),
                    child: Image.file(
                      File(widget.image.path),
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_processing) ...[
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppEditorial.ink,
                        strokeWidth: 2.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mengirim ke AI vision…',
                      style: AppEditorial.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppEditorial.inkSoft,
                      ),
                    ),
                  ] else if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppEditorial.rustSoft,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsRegular.warningCircle,
                              color: AppEditorial.rust, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppEditorial.sans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _start,
                      child: const Text('Coba lagi'),
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
