import 'package:flutter/material.dart';
import '../../utils/snackbar_helpers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notifications_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/health_data_provider.dart';
import '../../utils/sugar_classification.dart';

class AddSugarScreen extends ConsumerStatefulWidget {
  const AddSugarScreen({super.key});

  @override
  ConsumerState<AddSugarScreen> createState() => _AddSugarScreenState();
}

class _AddSugarScreenState extends ConsumerState<AddSugarScreen> {
  SugarType? _selectedType;
  
  final _sugarController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _sugarController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _sugarController.removeListener(_onInputChanged);
    _sugarController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // Rebuilds UI for live classification badge update
    setState(() {});
  }

  bool get _isFormValid {
    if (_selectedType == null) return false;
    double val = double.tryParse(_sugarController.text) ?? 0;
    return val >= 20 && val <= 600;
  }

  void _onSave() async {
    if (!_isFormValid || _selectedType == null) return;

    final val = double.parse(_sugarController.text);
    
    // Combine Date & Time
    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Stringify type for the provider mockup
    String typeStr;
    switch (_selectedType!) {
      case SugarType.fasting: typeStr = 'Fasting'; break;
      case SugarType.postMeal: typeStr = 'Post-meal'; break;
      case SugarType.random: typeStr = 'Random'; break;
    }

    // Insert 
    final repo = ref.read(healthRepoProvider);
    final record = SugarRecord(
      id: const Uuid().v4(),
      glucose: val,
      type: typeStr,
      date: combinedDateTime,
    );
    
    await repo.addSugar(record);

    ref.read(notificationsProvider.notifier).add(
      type: AppNotificationType.sugar,
      title: 'शुगर रिकॉर्ड किया गया / Sugar recorded',
      body: '${val.toStringAsFixed(0)} mg/dL · $typeStr',
    );

    if (!mounted) return;
    showSuccessSnackBar(context, 'शुगर सहेजी गई / Sugar Saved');

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
        title: const Text('शुगर जोड़ें / Add Sugar'),
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
              Text(
                'किस समय की शुगर है?',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              SegmentedButton<SugarType>(
                segments: const [
                  ButtonSegment(value: SugarType.fasting, label: Text('खाली पेट\n(Fasting)')),
                  ButtonSegment(value: SugarType.postMeal, label: Text('खाने के बाद\n(Post-meal)')),
                  ButtonSegment(value: SugarType.random, label: Text('कभी भी\n(Random)')),
                ],
                selected: _selectedType != null ? {_selectedType!} : <SugarType>{},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    // Trigger haptic feedback visually by revealing map
                  });
                },
                multiSelectionEnabled: false,
                emptySelectionAllowed: true,
              ),

              const SizedBox(height: 32),

              // Animated Reveal Form
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _selectedType == null 
                  ? const SizedBox(width: double.infinity)
                  : _buildDataEntryForm(theme, colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataEntryForm(ThemeData theme, ColorScheme colorScheme) {
    return Column(
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
                  controller: _sugarController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  maxLength: 5,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'शुगर का स्तर (Sugar Level)',
                    floatingLabelAlignment: FloatingLabelAlignment.center,
                    hintText: '000',
                    suffixText: 'mg/dL',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Live Classification Chip
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildClassificationChip(colorScheme),
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
            hintText: 'जैसे: मिठाई खाने के बाद...',
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
          child: const Text('शुगर सहेजें / Save Sugar', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 32), 
      ],
    );
  }

  Widget _buildClassificationChip(ColorScheme colorScheme) {
    if (_selectedType == null) return const SizedBox.shrink();
    
    double val = double.tryParse(_sugarController.text) ?? 0;
    if (val == 0) return const SizedBox(width: double.infinity, height: 32); 

    final level = SugarClassification.getLevel(_selectedType!, val);
    
    return Container(
      key: ValueKey(level),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: SugarClassification.getBgColor(level, colorScheme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        SugarClassification.getLabel(level),
        style: TextStyle(color: SugarClassification.getFgColor(level, colorScheme), fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
