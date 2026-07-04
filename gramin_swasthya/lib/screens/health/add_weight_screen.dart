import 'package:flutter/material.dart';
import '../../utils/snackbar_helpers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notifications_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/health_data_provider.dart';
import '../../utils/bmi_calculator.dart';

class AddWeightScreen extends ConsumerStatefulWidget {
  const AddWeightScreen({super.key});

  @override
  ConsumerState<AddWeightScreen> createState() => _AddWeightScreenState();
}

class _AddWeightScreenState extends ConsumerState<AddWeightScreen> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController(); // Optional, but triggers BMI logic if present
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_onInputChanged);
    _heightController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _weightController.removeListener(_onInputChanged);
    _heightController.removeListener(_onInputChanged);
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // Rebuilds UI to evaluate if the Live BMI Card should show up
    setState(() {});
  }

  bool get _isFormValid {
    double w = double.tryParse(_weightController.text) ?? 0;
    return w >= 20 && w <= 300;
  }

  void _onSave() async {
    if (!_isFormValid) return;

    final val = double.parse(_weightController.text);
    
    // Combine Date & Time
    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Insert to repo
    final repo = ref.read(healthRepoProvider);
    final record = WeightRecord(
      id: const Uuid().v4(),
      weight: val,
      date: combinedDateTime,
    );
    
    await repo.addWeight(record);

    ref.read(notificationsProvider.notifier).add(
      type: AppNotificationType.weight,
      title: 'वजन रिकॉर्ड किया गया / Weight recorded',
      body: '${val.toStringAsFixed(1)} kg',
    );

    if (!mounted) return;
    showSuccessSnackBar(context, 'वजन सहेजा गया / Weight Saved');

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
        title: const Text('वजन जोड़ें / Add Weight'),
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                        maxLength: 5,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'वजन / Weight',
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          hintText: '00.0',
                          suffixText: 'किग्रा (kg)',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                        maxLength: 5,
                        decoration: const InputDecoration(
                          labelText: 'लंबाई / Height (वैकल्पिक)',
                          hintText: 'e.g. 170',
                          suffixText: 'सेमी (cm)',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Animated BMI Reveal ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _buildLiveBmiCard(theme, colorScheme),
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
                      title: Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)),
                      onTap: _pickDate,
                    ),
                    const Divider(height: 0, indent: 48),
                    ListTile(
                      leading: const Icon(Icons.schedule, size: 20),
                      title: Text(_selectedTime.format(context)),
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
                decoration: const InputDecoration(
                  labelText: 'नोट्स (वैकल्पिक)',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('वजन सहेजें / Save Weight', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 32), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBmiCard(ThemeData theme, ColorScheme colorScheme) {
    double w = double.tryParse(_weightController.text) ?? 0;
    double h = double.tryParse(_heightController.text) ?? 0;

    // Only show if BOTH fields are realistically populated
    if (w < 10 || w > 300 || h < 50 || h > 250) {
      return const SizedBox(key: ValueKey('empty'), width: double.infinity);
    }

    final double bmi = BmiCalculator.calculate(w, h);
    final BmiCategory category = BmiCalculator.classify(bmi);

    return Card(
      key: const ValueKey('visible'),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest, // M3 filled card style equivalent
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text(
                  'BMI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  bmi.toStringAsFixed(1),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60, child: VerticalDivider(thickness: 1)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BmiCalculator.getLabelHindi(category),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: BmiCalculator.getBgColor(category, colorScheme),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    category.name.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: BmiCalculator.getFgColor(category, colorScheme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
