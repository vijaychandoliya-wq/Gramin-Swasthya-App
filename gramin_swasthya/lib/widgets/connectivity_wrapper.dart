import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    _checkInitialStatus();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialStatus() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool offline = results.contains(ConnectivityResult.none);
    
    // If was offline and now online, trigger sync
    if (_isOffline && !offline) {
      _triggerSync();
    }

    setState(() {
      _isOffline = offline;
    });
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    
    try {
      await SyncService.instance.syncAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('डेटा सिंक हुआ / Data Synced'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Quietly fail
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: (_isOffline || _isSyncing) ? 36 : 0,
          color: _isSyncing ? colorScheme.secondaryContainer : const Color(0xFF1C1B1F),
          child: (_isOffline || _isSyncing)
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSyncing ? Icons.sync : Icons.cloud_off,
                        size: 14,
                        color: _isSyncing ? colorScheme.onSecondaryContainer : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSyncing 
                          ? "डेटा सिंक हो रहा है... / Syncing..."
                          : "ऑफलाइन — डेटा सुरक्षित है / Offline",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isSyncing ? colorScheme.onSecondaryContainer : Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
