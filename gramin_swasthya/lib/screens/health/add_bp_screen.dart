import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/health_data_provider.dart';
import '../../utils/bp_calculator.dart';

class AddBpScreen extends ConsumerStatefulWidget {
  const AddBpScreen({super.key});

  @override
  ConsumerState<AddBpScreen> createState() => _AddBpScreenState();
}

class _AddBpScreenState extends ConsumerState<AddBpScreen> {
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _pulseController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _sysController.addListener(_onInputChanged);
    _diaController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _sysController.removeListener(_onInputChanged);
    _diaController.removeListener(_onInputChanged);
    _sysController.dispose();
    _diaController.dispose();
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
  }

  BPResult? get _bpResult {
    int sys = int.tryParse(_sysController.text) ?? 0;
    int dia = int.tryParse(_diaController.text) ?? 0;
    return BPCalculator.calculate(sys, dia);
  }

  bool get _isFormValid {
    int sys = int.tryParse(_sysController.text) ?? 0;
    int dia = int.tryParse(_diaController.text) ?? 0;
    return sys >= 50 && sys <= 250 && dia >= 40 && dia <= 150;
  }

  void _onSave() async {
    if (!_isFormValid) return;

    final sys = int.parse(_sysController.text);
    final dia = int.parse(_diaController.text);

    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final repo = ref.read(healthRepoProvider);
    final record = BpRecord(
      id: const Uuid().v4(),
      systolic: sys,
      diastolic: dia,
      date: combinedDateTime,
    );

    await repo.addBp(record);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: LocalizedText('BP सहेजा गया  / BP Saved')),
    );

    context.pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const LocalizedText('BP जोड़ें / Add BP'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Readings Card ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'ब्लड प्रेशर',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _sysController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 3,
                        decoration: InputDecoration(
                          labelText: AppLanguage.text('ऊपरी BP (Systolic)'),
                          hintText: AppLanguage.text('e.g. 120'),
                          suffixText: AppLanguage.text('mmHg'),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _diaController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 3,
                        decoration: InputDecoration(
                          labelText: AppLanguage.text('नीचे BP (Diastolic)'),
                          hintText: AppLanguage.text('e.g. 80'),
                          suffixText: AppLanguage.text('mmHg'),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _pulseController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 3,
                        decoration: InputDecoration(
                          labelText:
                              AppLanguage.text('नाड़ी (Pulse) — वैकल्पिक'),
                          hintText: AppLanguage.text('e.g. 72'),
                          suffixText: AppLanguage.text('bpm'),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Live Classification + Advice
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildClassificationCard(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Date/Time Card ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today, size: 20),
                      title: LocalizedText(DateFormat('EEEE, d MMMM yyyy')
                          .format(_selectedDate)),
                      onTap: _pickDate,
                    ),
                    const Divider(height: 0, indent: 48),
                    ListTile(
                      leading: const Icon(Icons.schedule, size: 20),
                      title: LocalizedText(_selectedTime.format(context)),
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- Notes ---
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: AppLanguage.text('नोट्स (वैकल्पिक)'),
                  hintText:
                      AppLanguage.text('जैसे: दवाई लेने के 2 घंटे बाद...'),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 32),

              // --- Save Button ---
              FilledButton(
                onPressed: _isFormValid ? _onSave : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const LocalizedText('BP सहेजें / Save BP',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassificationCard() {
    final result = _bpResult;
    if (result == null) {
      return const SizedBox(
          key: ValueKey('empty'), width: double.infinity, height: 32);
    }

    return Container(
      key: ValueKey(result.category),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            '${result.categoryHindi} (${result.category})',
            style: TextStyle(
              color: result.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          LocalizedText(
            result.advice,
            style: TextStyle(
              color: result.textColor.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
