import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kCurrentVersion = '1.1.0';
const String _kVersionUrl =
    'https://raw.githubusercontent.com/ameralking888-maker/alpha-net-store/main/version.json';

class UpdateService {
  static Future<Map<String, dynamic>?> _fetch() async {
    if (kIsWeb) return null; // Web updates automatically via Netlify
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(Uri.parse(_kVersionUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'mosque-students-app');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns the latest version info if an update is available, null otherwise.
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    final data = await _fetch();
    if (data == null) return null;
    final latest = (data['version'] as String?) ?? '';
    return _isNewer(latest, _kCurrentVersion) ? data : null;
  }

  /// مرحلة الأمان التي أعلنها version.json (1 = انتقالية، 2 = القواعد الصارمة).
  static Future<int> fetchSecurityPhase() async {
    final data = await _fetch();
    return (data?['security_phase'] as num?)?.toInt() ?? 1;
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  /// Shows the update dialog if an update is available.
  static Future<void> checkAndPrompt(BuildContext context) async {
    final data = await checkForUpdate();
    if (data == null) return;
    if (!context.mounted) return;

    final version = data['version'] as String? ?? '';
    final downloadUrl = data['download_url'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    // min_version: النسخ الأقدم منها لا يمكنها المتابعة بدون تحديث
    final forced = _isNewer(data['min_version'] as String? ?? '0.0.0', _kCurrentVersion);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
       canPop: !forced,
       child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update, color: Colors.green, size: 26),
            ),
            const SizedBox(width: 12),
            const Text('تحديث متوفر', style: TextStyle(fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('النسخة الجديدة: $version',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(notes, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ],
              const SizedBox(height: 12),
              Text(
                  forced
                      ? 'هذا التحديث مطلوب للمتابعة، لأنه يتضمن تحسينات أمان.'
                      : 'يُنصح بالتحديث للحصول على أحدث الميزات والإصلاحات.',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
          actions: [
            if (!forced)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('لاحقاً', style: TextStyle(color: Colors.grey.shade600)),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('تحميل التحديث'),
              onPressed: () async {
                if (!forced) Navigator.pop(ctx);
                if (downloadUrl.isNotEmpty) {
                  await launchUrl(Uri.parse(downloadUrl),
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
       ),
      ),
    );
  }
}
