import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AlphaNetBranding extends StatelessWidget {
  const AlphaNetBranding({super.key});

  static const _links = [
    _LinkItem(
      icon: Icons.language,
      label: 'الموقع الإلكتروني',
      url: 'https://alpha-net.netlify.app/',
      color: Color(0xFF00BCD4),
    ),
    _LinkItem(
      icon: Icons.facebook,
      label: 'فيسبوك',
      url: 'https://www.facebook.com/share/18PaVUxkfj/',
      color: Color(0xFF1877F2),
    ),
    _LinkItem(
      icon: Icons.camera_alt,
      label: 'إنستغرام',
      url: 'https://www.instagram.com/alphanet586?igsh=OGk1bGh6Z3FjZGFn',
      color: Color(0xFFE1306C),
    ),
    _LinkItem(
      icon: Icons.chat,
      label: 'قناة واتساب',
      url: 'https://whatsapp.com/channel/0029VbCaXhp23n3dXVK9nT1j',
      color: Color(0xFF25D366),
    ),
  ];

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الرابط')),
        );
      }
    }
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LinksSheet(links: _links, onTap: (url) => _open(context, url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1628),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/alphanet_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.code,
              color: Color(0xFF00E5FF),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Sheet ───────────────────────────────────────────────────────────

class _LinksSheet extends StatelessWidget {
  final List<_LinkItem> links;
  final void Function(String url) onTap;
  const _LinksSheet({required this.links, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Logo + Name
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/alphanet_logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.code,
                      color: Color(0xFF00E5FF),
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ألفا نت للبرمجة',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'ALPHA NET for PROGRAMMING',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    'حماة - سوريا',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Links
          ...links.map((link) => _LinkTile(link: link, onTap: () => onTap(link.url))),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final _LinkItem link;
  final VoidCallback onTap;
  const _LinkTile({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: link.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(link.icon, color: link.color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              link.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

class _LinkItem {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  const _LinkItem(
      {required this.icon,
      required this.label,
      required this.url,
      required this.color});
}
