import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/responsive.dart';

class SyncStatusBar extends StatefulWidget {
  const SyncStatusBar({super.key});

  @override
  State<SyncStatusBar> createState() => _SyncStatusBarState();
}

class _SyncStatusBarState extends State<SyncStatusBar> {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOnline = results.any((r) => r != ConnectivityResult.none));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = result.any((r) => r != ConnectivityResult.none));
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    if (_isOnline) return const SizedBox.shrink(); // مخفي إذا في اتصال

    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: EdgeInsets.symmetric(vertical: r.sp(6), horizontal: r.sp(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: r.iconSize(16)),
          SizedBox(width: r.sp(6)),
          Text(
            'غير متصل — سيتم المزامنة عند عودة الإنترنت',
            style: TextStyle(
              color: Colors.white,
              fontSize: r.fontSize(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// أيقونة صغيرة تظهر في AppBar
class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOnline = results.any((r) => r != ConnectivityResult.none));
    });
    _check();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final r = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = r.any((x) => x != ConnectivityResult.none));
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isOnline ? 'متزامن مع السحابة ☁️' : 'غير متصل بالإنترنت',
      child: Icon(
        _isOnline ? Icons.cloud_done : Icons.cloud_off,
        color: _isOnline ? Colors.greenAccent : Colors.orange,
        size: 22,
      ),
    );
  }
}
