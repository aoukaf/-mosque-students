import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import 'home_screen.dart';
import 'awqaf_screen.dart';

enum _SetupPage { initial, newMosque, showId, existing, awqaf }

class MosqueSetupScreen extends StatefulWidget {
  const MosqueSetupScreen({super.key});

  @override
  State<MosqueSetupScreen> createState() => _MosqueSetupScreenState();
}

class _MosqueSetupScreenState extends State<MosqueSetupScreen> {
  _SetupPage _page = _SetupPage.initial;

  final _mosqueNameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _existingPwCtrl = TextEditingController();
  final _awqafPwCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePw = true;
  bool _obscurePw2 = true;
  bool _obscureExisting = true;
  String? _error;
  String? _generatedId;

  int _logoTapCount = 0;

  // تقييد المحاولات الفاشلة - دائم عبر SharedPreferences
  static const _keyAttempts = 'login_failed_attempts';
  static const _keyLockUntil = 'login_lock_until_ms';
  int _failedAttempts = 0;
  DateTime? _lockUntil;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_keyAttempts) ?? 0;
    final lockMs = prefs.getInt(_keyLockUntil) ?? 0;
    final lockUntil = lockMs > 0 ? DateTime.fromMillisecondsSinceEpoch(lockMs) : null;
    if (mounted) {
      setState(() {
        _failedAttempts = attempts;
        _lockUntil = lockUntil;
      });
    }
  }

  Future<void> _saveLockState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAttempts, _failedAttempts);
    await prefs.setInt(_keyLockUntil, _lockUntil?.millisecondsSinceEpoch ?? 0);
  }

  Future<void> _resetLockState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAttempts);
    await prefs.remove(_keyLockUntil);
    _failedAttempts = 0;
    _lockUntil = null;
  }

  @override
  void dispose() {
    _mosqueNameCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    _idCtrl.dispose();
    _existingPwCtrl.dispose();
    _awqafPwCtrl.dispose();
    super.dispose();
  }

  String _hashPassword(String mosqueId, String password) =>
      sha256.convert(utf8.encode('$mosqueId:$password')).toString();

  String _hashAwqaf(String password) =>
      sha256.convert(utf8.encode('awqaf:$password')).toString();

  bool _isLocked() {
    if (_lockUntil == null) return false;
    if (DateTime.now().isAfter(_lockUntil!)) {
      _failedAttempts = 0;
      _lockUntil = null;
      _saveLockState(); // fire-and-forget: مسح القفل المنتهي من الذاكرة الدائمة
      return false;
    }
    return true;
  }

  String _lockMessage() {
    final remaining = _lockUntil!.difference(DateTime.now()).inSeconds;
    return 'محاولات كثيرة، انتظر $remaining ثانية';
  }

  String _generateMosqueId() {
    const digits = '0123456789';
    final rng = Random.secure();
    return List.generate(12, (_) => digits[rng.nextInt(digits.length)]).join();
  }

  String _formatId(String id) =>
      '${id.substring(0, 4)}-${id.substring(4, 8)}-${id.substring(8, 12)}';

  Future<void> _loginAwqaf() async {
    final pw = _awqafPwCtrl.text.trim();
    if (pw.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_isLocked()) {
      setState(() => _error = _lockMessage());
      return;
    }
    setState(() { _loading = true; _error = null; });

    final online = await SyncService().isOnline;
    if (!online) {
      setState(() { _error = 'يلزم الاتصال بالإنترنت'; _loading = false; });
      return;
    }

    try {
      final hash = _hashAwqaf(pw);
      final exists = await SyncService().awqafExists();
      if (!exists) {
        await SyncService().createAwqaf(hash);
      } else {
        final valid = await SyncService().verifyAwqaf(hash);
        if (!valid) {
          _failedAttempts++;
          if (_failedAttempts >= 3) {
            _lockUntil = DateTime.now().add(const Duration(seconds: 30));
          }
          await _saveLockState();
          setState(() {
            _error = _failedAttempts >= 3
                ? _lockMessage()
                : 'كلمة المرور غير صحيحة (${3 - _failedAttempts} محاولات متبقية)';
            _loading = false;
          });
          return;
        }
      }
      await _resetLockState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SyncService.userRoleKey, 'awqaf');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AwqafScreen()),
        );
      }
    } catch (e) {
      setState(() { _error = 'حدث خطأ، تأكد من اتصالك بالإنترنت'; _loading = false; });
    }
  }

  Future<void> _createMosque() async {
    final name = _mosqueNameCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    final pw2 = _pw2Ctrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم المسجد');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (pw != pw2) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final online = await SyncService().isOnline;
    if (!online) {
      setState(() {
        _error = 'يلزم الاتصال بالإنترنت لإنشاء المسجد';
        _loading = false;
      });
      return;
    }

    try {
      final id = _generateMosqueId();
      await SyncService().createMosque(id, _hashPassword(id, pw), name, pw);
      SyncService().initialize(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SyncService.mosqueIdKey, id);
      setState(() {
        _generatedId = id;
        _page = _SetupPage.showId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ، تأكد من اتصالك بالإنترنت';
        _loading = false;
      });
    }
  }

  Future<void> _connectMosque() async {
    final raw = _idCtrl.text.trim().replaceAll('-', '').toUpperCase();
    final pw = _existingPwCtrl.text.trim();

    if (raw.length != 12) {
      setState(() => _error = 'رقم المسجد يجب أن يكون 12 حرفاً (مثال: XXXX-XXXX-XXXX)');
      return;
    }
    if (pw.isEmpty) {
      setState(() => _error = 'الرجاء إدخال كلمة المرور');
      return;
    }

    if (_isLocked()) {
      setState(() => _error = _lockMessage());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final online = await SyncService().isOnline;
    if (!online) {
      setState(() {
        _error = 'يلزم الاتصال بالإنترنت للتحقق من رقم المسجد';
        _loading = false;
      });
      return;
    }

    try {
      final valid = await SyncService().verifyMosque(raw, _hashPassword(raw, pw));
      if (!valid) {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _lockUntil = DateTime.now().add(const Duration(seconds: 30));
        }
        await _saveLockState();
        setState(() {
          _error = _failedAttempts >= 3
              ? _lockMessage()
              : 'رقم المسجد أو كلمة المرور غير صحيحة (${3 - _failedAttempts} محاولات متبقية)';
          _loading = false;
        });
        return;
      }
      await _resetLockState();
      SyncService().initialize(raw);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SyncService.mosqueIdKey, raw);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ، تأكد من اتصالك بالإنترنت';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.primaryGreen,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: switch (_page) {
              _SetupPage.initial   => _buildInitial(),
              _SetupPage.newMosque => _buildNewMosque(),
              _SetupPage.showId    => _buildShowId(),
              _SetupPage.existing  => _buildExisting(),
              _SetupPage.awqaf     => _buildAwqaf(),
            },
          ),
        ),
      ),
    );
  }

  // =================== شاشة الاختيار ===================

  Widget _buildInitial() {
    return Column(
      key: const ValueKey('initial'),
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _logoTapCount++;
                  if (_logoTapCount >= 10) {
                    _logoTapCount = 0;
                    setState(() { _page = _SetupPage.awqaf; _error = null; });
                  }
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mosque, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'سجلات طلاب المسجد',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'أولاً، قم بتهيئة مسجدك',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OptionCard(
                  icon: Icons.add_circle_outline,
                  title: 'إنشاء مسجد جديد',
                  subtitle: 'سجّل مسجدك وابدأ بإدخال البيانات',
                  color: AppTheme.primaryGreen,
                  onTap: () => setState(() {
                    _page = _SetupPage.newMosque;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('أو', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                _OptionCard(
                  icon: Icons.link_rounded,
                  title: 'الانضمام لمسجد موجود',
                  subtitle: 'أدخل رقم المسجد للوصول لبياناته',
                  color: Colors.blueGrey.shade700,
                  onTap: () => setState(() {
                    _page = _SetupPage.existing;
                    _error = null;
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =================== شاشة مسجد جديد ===================

  Widget _buildNewMosque() {
    return Column(
      key: const ValueKey('newMosque'),
      children: [
        _TopBar(
          title: 'إنشاء مسجد جديد',
          onBack: () => setState(() {
            _page = _SetupPage.initial;
            _error = null;
          }),
        ),
        Expanded(
          child: _WhiteCard(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سيتم توليد رقم مميز لمسجدك تلقائياً.\nاحتفظ بكلمة المرور لاستخدامها على أجهزة أخرى.',
                    style: TextStyle(color: Colors.grey.shade600, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  const _Label('اسم المسجد'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mosqueNameCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'مثال: مسجد النور',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Label('كلمة المرور'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _pwCtrl,
                    hint: 'أدخل كلمة المرور',
                    obscure: _obscurePw,
                    onToggle: () => setState(() => _obscurePw = !_obscurePw),
                  ),
                  const SizedBox(height: 16),
                  const _Label('تأكيد كلمة المرور'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _pw2Ctrl,
                    hint: 'أعد إدخال كلمة المرور',
                    obscure: _obscurePw2,
                    onToggle: () => setState(() => _obscurePw2 = !_obscurePw2),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(_error!),
                  ],
                  const SizedBox(height: 28),
                  _ActionButton(
                    label: 'إنشاء المسجد',
                    loading: _loading,
                    color: AppTheme.primaryGreen,
                    onPressed: _createMosque,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =================== شاشة عرض الرقم المولّد ===================

  Widget _buildShowId() {
    final formatted = _formatId(_generatedId!);
    return Column(
      key: const ValueKey('showId'),
      children: [
        const _TopBar(title: 'تم إنشاء المسجد'),
        Expanded(
          child: _WhiteCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      size: 64, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 24),
                const Text(
                  'تم إنشاء مسجدك بنجاح!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'رقم مسجدك الخاص',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatted,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: formatted));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ رقم المسجد'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'احتفظ بهذا الرقم وكلمة المرور!\nستحتاجهما عند تثبيت التطبيق على جهاز آخر.',
                          style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _ActionButton(
                  label: 'بدء الاستخدام',
                  loading: false,
                  color: AppTheme.primaryGreen,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =================== شاشة الانضمام لمسجد موجود ===================

  Widget _buildExisting() {
    return Column(
      key: const ValueKey('existing'),
      children: [
        _TopBar(
          title: 'الانضمام لمسجد موجود',
          onBack: () => setState(() {
            _page = _SetupPage.initial;
            _error = null;
          }),
        ),
        Expanded(
          child: _WhiteCard(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أدخل رقم المسجد الذي حصلت عليه مسبقاً مع كلمة المرور.',
                    style: TextStyle(color: Colors.grey.shade600, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  const _Label('رقم المسجد'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idCtrl,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX',
                      hintStyle: const TextStyle(
                          letterSpacing: 3,
                          color: Colors.grey,
                          fontSize: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Label('كلمة المرور'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _existingPwCtrl,
                    hint: 'أدخل كلمة المرور',
                    obscure: _obscureExisting,
                    onToggle: () =>
                        setState(() => _obscureExisting = !_obscureExisting),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(_error!),
                  ],
                  const SizedBox(height: 28),
                  _ActionButton(
                    label: 'الانضمام',
                    loading: _loading,
                    color: Colors.blueGrey.shade700,
                    onPressed: _connectMosque,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =================== شاشة الأوقاف ===================

  Widget _buildAwqaf() {
    return Column(
      key: const ValueKey('awqaf'),
      children: [
        _TopBar(
          title: 'دخول الأوقاف',
          onBack: () => setState(() {
            _page = _SetupPage.initial;
            _error = null;
            _awqafPwCtrl.clear();
          }),
        ),
        Expanded(
          child: _WhiteCard(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance, color: Colors.amber.shade800, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'هذه اللوحة مخصصة لمتابعة جميع المساجد.\nللدخول الأول: ستُنشأ كلمة المرور تلقائياً.',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _Label('كلمة مرور الأوقاف'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _awqafPwCtrl,
                    hint: 'أدخل كلمة المرور',
                    obscure: _obscurePw,
                    onToggle: () => setState(() => _obscurePw = !_obscurePw),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(_error!),
                  ],
                  const SizedBox(height: 28),
                  _ActionButton(
                    label: 'دخول',
                    loading: _loading,
                    color: Colors.amber.shade800,
                    onPressed: _loginAwqaf,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =================== مكونات مساعدة ===================

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  const _TopBar({required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: onBack,
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordField(
      {required this.controller,
      required this.hint,
      required this.obscure,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton(
      {required this.label,
      required this.loading,
      required this.color,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _OptionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
