import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _otpSent = false;
  bool _loading = false;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // TODO: Remove temp OTP bypass before production release
  static const _tempOtp = '1234';

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      _showError('कृपया 10 अंकों का मोबाइल नंबर दर्ज करें / Enter a 10-digit number');
      return;
    }

    setState(() => _loading = true);

    // Temp OTP bypass — skip Firebase, go straight to OTP input step
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _otpSent = true;
      _loading = false;
    });
    _startResendTimer();
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      _showError('कृपया 4 अंकों का OTP दर्ज करें / Enter 4-digit OTP');
      return;
    }

    if (otp == _tempOtp) {
      setState(() => _loading = true);
      await Future.delayed(const Duration(milliseconds: 300));
      _onAuthSuccess();
    } else {
      _showError('गलत OTP / Invalid OTP — use 1234');
    }
  }

  Future<void> _onAuthSuccess() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'temp_token_${DateTime.now().millisecondsSinceEpoch}');
    if (!mounted) return;
    context.go('/add-family-member');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('नया खाता / New Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _phoneController,
                  enabled: !_otpSent, // Disable if OTP sent
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'मोबाइल नंबर / Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: !_otpSent 
                    ? _buildStep1(theme) 
                    : _buildStep2(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return FilledButton(
      key: const ValueKey('step1'),
      onPressed: _loading ? null : _sendOTP,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
      ),
      child: _loading 
        ? SizedBox(
            width: 18, 
            height: 18, 
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)
          )
        : const Text('OTP भेजें / Send OTP'),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _otpController,
          autofocus: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'OTP दर्ज करें / Enter OTP',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _resendCountdown > 0 || _loading ? null : _sendOTP,
              child: const Text('OTP दोबारा भेजें / Resend'),
            ),
            if (_resendCountdown > 0)
              Text(
                '$_resendCountdown s',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _verifyOTP,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          child: _loading 
            ? SizedBox(
                width: 18, 
                height: 18, 
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)
              )
            : const Text('सत्यापित करें / Verify'),
        ),
      ],
    );
  }
}
