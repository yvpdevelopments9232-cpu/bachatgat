import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/app_config.dart';

class GlobalOfflineWrapper extends StatefulWidget {
  final Widget child;
  const GlobalOfflineWrapper({super.key, required this.child});

  @override
  State<GlobalOfflineWrapper> createState() => _GlobalOfflineWrapperState();
}

class _GlobalOfflineWrapperState extends State<GlobalOfflineWrapper> {
  bool _isOffline = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isOfflineMode) return;
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOffline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isOfflineMode) {
      return widget.child;
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_isOffline)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.92),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.redAccent, size: 80),
                        const SizedBox(height: 24),
                        const Text(
                          'इंटरनेट कनेक्शन नाही',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sakhi Bachat Gat Online Edition चालवण्यासाठी इंटरनेट आवश्यक आहे.\nकृपया इंटरनेट चालू करा किंवा ऑफलाइन आवृत्ती वापरा.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'कनेक्शनची वाट पाहत आहे...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
