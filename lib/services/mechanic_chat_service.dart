import 'package:supabase_flutter/supabase_flutter.dart';

/// Menghubungkan app ke Edge Function `vehicle-assistant` di Supabase, yang
/// memanggil LLM dengan peran "montir ahli". API key LLM disimpan sebagai
/// secret di Edge Function — TIDAK pernah ada di aplikasi.
class MechanicChatService {
  static const String functionName = 'vehicle-assistant';

  /// [history] daftar pesan urut lama→baru: {'role': 'user'|'assistant',
  /// 'content': '...'}. [vehicleContext] ringkasan kendaraan pengguna.
  static Future<String> ask({
    required List<Map<String, String>> history,
    required String vehicleContext,
  }) async {
    final client = Supabase.instance.client;

    try {
      final res = await client.functions.invoke(
        functionName,
        body: {
          'messages': history,
          'vehicle_context': vehicleContext,
        },
      );

      final data = res.data;
      final reply = (data is Map && data['reply'] is String)
          ? (data['reply'] as String).trim()
          : '';
      if (reply.isEmpty) {
        throw MechanicChatException('Balasan kosong dari asisten.');
      }
      return reply;
    } on FunctionException catch (e) {
      // invoke() melempar untuk status non-2xx. Ambil pesan error asli
      // dari body function ({error: ...}) supaya penyebabnya jelas.
      String msg;
      final d = e.details;
      if (d is Map && d['error'] != null) {
        msg = d['error'].toString();
      } else if (d is String && d.trim().isNotEmpty) {
        msg = d.trim();
      } else {
        msg = 'Gagal (${e.status}${e.reasonPhrase != null ? ' ${e.reasonPhrase}' : ''}).';
      }
      throw MechanicChatException(msg);
    }
  }
}

class MechanicChatException implements Exception {
  MechanicChatException(this.message);
  final String message;
  @override
  String toString() => message;
}
