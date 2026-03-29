import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> with SingleTickerProviderStateMixin {
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  final LocalAuthentication _auth = LocalAuthentication();
  bool _showBiometric = false;
  bool _showError = false;

  // Lockout State
  int _failedAttempts = 0;
  bool _isLockedOut = false;
  int _lockoutTimerValue = 30;
  Timer? _lockoutTimer;

  // Mock Family Name for UI
  final String _familyName = 'Vijay Kumar';

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (_) => FocusNode());
    _controllers = List.generate(4, (_) => TextEditingController());

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-0.1, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.1, 0), end: const Offset(0.1, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.1, 0), end: const Offset(-0.1, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.1, 0), end: const Offset(0.1, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.1, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _checkBiometrics();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _showBiometric = canCheck && isSupported;
        });
      }
      
      // Auto-prompt biometrics if available
      if (_showBiometric) {
        _authenticateWithBiometrics();
      }
    } on PlatformException catch (_) {
      // Ignore if not supported/available
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isLockedOut) return;
    
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Gramin Swasthya',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        context.go('/home');
      }
    } on PlatformException catch (_) {
      // User canceled or failed
    }
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  void _clearFields() {
    for (var c in _controllers) {
      c.clear();
    }
  }

  bool _isPinComplete() {
    return _controllers.every((c) => c.text.isNotEmpty);
  }

  void _onInputChanged(String value, int index) {
    if (_isLockedOut) return;

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[3].unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    setState(() => _showError = false);
  }

  void _handleFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _showError = true;
    });

    if (_failedAttempts >= 5) {
      _startLockout();
    } else {
      _triggerShake();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
          _clearFields();
          _focusNodes[0].requestFocus();
        }
      });
    }
  }

  void _startLockout() {
    setState(() {
      _isLockedOut = true;
      _lockoutTimerValue = 30;
      _clearFields();
    });
    
    for (var n in _focusNodes) {
      n.unfocus();
    }

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutTimerValue > 0) {
        setState(() => _lockoutTimerValue--);
      } else {
        timer.cancel();
        setState(() {
          _isLockedOut = false;
          _failedAttempts = 0;
        });
        _focusNodes[0].requestFocus();
      }
    });
  }

  Future<void> _login() async {
    if (_isLockedOut || !_isPinComplete()) return;

    final enteredPin = _controllers.map((c) => c.text).join();
    
    // Hash input
    final Digest digest = sha256.convert(utf8.encode(enteredPin));
    final String hashedEnteredPin = digest.toString();

    // Read stored
    const storage = FlutterSecureStorage();
    final storedHash = await storage.read(key: 'pin_hash');

    if (storedHash == null) {
      // Edge case: Setup wasn't completed properly
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN not found. Please set up again.')),
        );
        context.go('/pin-setup');
      }
      return;
    }

    if (hashedEnteredPin == storedHash) {
      if (mounted) context.go('/home');
    } else {
      _handleFailedAttempt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 64),
                
                // Avatar Header
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    _familyName.isNotEmpty ? _familyName[0].toUpperCase() : 'U',
                    style: textTheme.displaySmall?.copyWith(color: colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'नमस्ते, $_familyName',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'अपना PIN दर्ज करें',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant, // Even on primaryContainer, this works for muted text
                  ),
                ),
                const SizedBox(height: 48),

                // PIN Entry Row (reusing approach from Setup)
                SlideTransition(
                  position: _shakeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            enabled: !_isLockedOut,
                            obscureText: true,
                            maxLength: 1,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _showError ? colorScheme.error : colorScheme.primary,
                                  width: 2.0,
                                ),
                              ),
                            ),
                            onChanged: (value) => _onInputChanged(value, index),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // Actions or Lockout
                if (_isLockedOut) ...[
                  LinearProgressIndicator(
                    value: _lockoutTimerValue / 30,
                    backgroundColor: colorScheme.surface,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'तालाबंद / Locked Out. ${_lockoutTimerValue}s',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ] else ...[
                  if (_showError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'PIN गलत है / Incorrect PIN',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: _isPinComplete() ? _login : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('लॉगिन / Login'),
                  ),
                  const SizedBox(height: 16),
                  if (_showBiometric)
                    FilledButton.tonalIcon(
                      onPressed: _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: const Text('Biometric Login'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                ],

                const SizedBox(height: 32),
                TextButton(
                  onPressed: () {
                    if (!_isLockedOut) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Forgot PIN flow not implemented yet'))
                       );
                    }
                  },
                  child: Text(
                    'PIN भूल गए? / Forgot PIN?',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
