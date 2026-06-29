import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Satu percakapan tersimpan (lokal, di perangkat).
class ChatConversation {
  ChatConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  String title;
  DateTime updatedAt;

  /// Tiap pesan: {'role': 'user'|'assistant', 'text': '...'}.
  List<Map<String, String>> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages,
      };

  factory ChatConversation.fromJson(Map<String, dynamic> j) {
    final rawMsgs = (j['messages'] as List?) ?? const [];
    return ChatConversation(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? 'Percakapan',
      updatedAt:
          DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      messages: rawMsgs
          .map<Map<String, String>>((e) => {
                'role': (e['role'] ?? 'assistant').toString(),
                'text': (e['text'] ?? '').toString(),
              })
          .toList(),
    );
  }
}

/// Penyimpanan riwayat chat di SharedPreferences (per perangkat).
class ChatStore {
  static const _key = 'mechanic_chat_conversations_v1';
  static const _maxConversations = 50;

  static Future<List<ChatConversation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final convos = list
          .map((e) => ChatConversation.fromJson(e as Map<String, dynamic>))
          .toList();
      convos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return convos;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<ChatConversation> convos) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = [...convos]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final capped = trimmed.take(_maxConversations).toList();
    await prefs.setString(
      _key,
      jsonEncode(capped.map((c) => c.toJson()).toList()),
    );
  }

  /// Tambah/-perbarui satu percakapan lalu simpan.
  static Future<List<ChatConversation>> upsert(
    ChatConversation convo,
  ) async {
    final all = await load();
    final idx = all.indexWhere((c) => c.id == convo.id);
    if (idx >= 0) {
      all[idx] = convo;
    } else {
      all.add(convo);
    }
    await saveAll(all);
    return load();
  }

  static Future<List<ChatConversation>> delete(String id) async {
    final all = await load();
    all.removeWhere((c) => c.id == id);
    await saveAll(all);
    return all;
  }
}
