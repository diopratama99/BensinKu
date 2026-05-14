import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';

/// Wrapper untuk Edge Functions `parse-fuel-receipt` dan `parse-fuel-voice`.
///
/// Voice flow:
///   1. UI panggil `speech_to_text` on-device untuk transkripsi
///   2. Kirim transcript ke `parseVoice()` -> ParsedRefuel
///
/// Receipt flow:
///   1. UI ambil foto via `image_picker`
///   2. Convert ke base64 + tebak mime
///   3. Kirim ke `parseReceipt()` -> ParsedRefuel
class RefuelParserService {
  RefuelParserService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Parse ucapan user (sudah ditranskripsi on-device) jadi draft pengisian.
  Future<ParsedRefuel> parseVoice(String transcript) async {
    final clean = transcript.trim();
    if (clean.isEmpty) {
      throw StateError('Ucapan kosong, coba bicara lebih jelas.');
    }

    final res = await _client.functions.invoke(
      'parse-fuel-voice',
      body: {'transcript': clean},
    );
    return _decode(res);
  }

  /// Parse foto struk SPBU jadi draft pengisian.
  Future<ParsedRefuel> parseReceipt(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return parseReceiptBytes(bytes, _guessMime(imageFile.path));
  }

  /// Versi yang menerima bytes langsung (mis. dari image_picker.readAsBytes).
  Future<ParsedRefuel> parseReceiptBytes(
    Uint8List bytes,
    String mime,
  ) async {
    if (bytes.isEmpty) {
      throw StateError('Foto kosong.');
    }
    // Server cap base64 di ~6.5MB, di sini kita reject sebelum encode.
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError(
        'Foto terlalu besar (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Coba foto ulang dengan resolusi lebih rendah.',
      );
    }

    final base64Image = base64Encode(bytes);
    final res = await _client.functions.invoke(
      'parse-fuel-receipt',
      body: {'image_base64': base64Image, 'mime': mime},
    );
    return _decode(res);
  }

  ParsedRefuel _decode(FunctionResponse res) {
    if (res.status >= 400) {
      throw StateError(_extractError(res));
    }
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Respon parser tidak valid.');
    }
    final refuel = data['refuel'];
    if (refuel is! Map<String, dynamic>) {
      throw StateError('AI tidak menemukan data pengisian.');
    }
    return ParsedRefuel.fromJson(refuel);
  }

  String _extractError(FunctionResponse res) {
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      final err = body['error'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (err is String && err.isNotEmpty) return _humanize(err);
    }
    return 'Parser gagal (HTTP ${res.status}).';
  }

  String _humanize(String code) {
    switch (code) {
      case 'no_vehicles':
        return 'Belum ada kendaraan. Tambahkan di profil dulu.';
      case 'no_fuel_products':
        return 'Master BBM kosong. Hubungi admin.';
      case 'no_refuel_parsed':
        return 'AI tidak mengenali ucapan/struk sebagai pengisian.';
      case 'image_too_large':
        return 'Foto terlalu besar.';
      case 'unsupported_mime':
        return 'Format foto tidak didukung (pakai JPG / PNG).';
      case 'empty_transcript':
        return 'Ucapan kosong.';
      case 'transcript_too_long':
        return 'Ucapan terlalu panjang (>600 karakter).';
      default:
        return 'Parser error: $code.';
    }
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
