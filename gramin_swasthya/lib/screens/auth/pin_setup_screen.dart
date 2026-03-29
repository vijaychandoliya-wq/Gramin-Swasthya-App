import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> with SingleTickerProviderStateMixin {
  int _step = 1;
  String _firstPin = '';
  bool _showError = false;

  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (_) => FocusNode());
    _controllers = List.generate(4, (_) => TextEditingController());

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Simple multi-sequence interpolation for a shake effect
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-0.1, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.1, 0), end: const Offset(0.1, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.1, 0), end: const Offset(-0.1, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.1, 0), end: const Offset(0.1, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.1, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  void _clearFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
  }

  bool _isPinComplete() {
    return _controllers.every((c) => c.text.isNotEmpty);
  }

  void _onInputChanged(String value, int index) {
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
    setState(() {
      _showError = false; // Hide error on new input
    });
  }

  Future<void> _onContinue() async {
    if (_step == 1) {
      _firstPin = _controllers.map((c) => c.text).join();
      setState(() {
        _step = 2;
        _clearFields();
      });
      _focusNodes[0].requestFocus();
    } else {
      final confirmPin = _controllers.map((c) => c.text).join();
      if (_firstPin == confirmPin) {
        // Success
        final Digest digest = sha256.convert(utf8.encode(_firstPin));
        final String hashedPin = digest.toString();

        const storage = FlutterSecureStorage();
        await storage.write(key: 'pin_hash', value: hashedPin);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pin_set', true);
        
        if (mounted) {
          // Changed to onboarding since task flow dictates setup -> onboarding -> home
          context.go('/home');
        }
      } else {
        // Mismatch
        setState(() {
          _showError = true;
        });
        _triggerShake();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _showError = false;
            _clearFields();
          });
          _focusNodes[0].requestFocus();
        }
      }
    }
  }

  void _onBackPressed() {
    if (_step == 2) {
      setState(() {
        _step = 1;
        _firstPin = '';
        _clearFields();
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('PIN सेट करें'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBackPressed,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _step == 1 ? 0.5 : 1.0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _step == 1 ? 'अपना 4-अंकीय PIN दर्ज करें' : 'PIN की पुष्टि करें',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
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
                                obscureText: true,
                                maxLength: 1,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  counterText: '', // Hide the 0/1 counter
                                  border: const OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _showError ? theme.colorScheme.error : theme.colorScheme.primary,
                                      width: 2.0,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _showError ? theme.colorScheme.error : theme.colorScheme.outline,
                                      width: 1.0,
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
                    
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _showError ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        'PIN मेल नहीं खाता',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _isPinComplete() ? _onContinue : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text('जारी / Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
