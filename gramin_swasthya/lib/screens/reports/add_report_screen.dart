import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/snackbar_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/reports_provider.dart';
import '../../providers/family_provider.dart';

class AddReportScreen extends ConsumerStatefulWidget {
  const AddReportScreen({super.key});

  @override
  ConsumerState<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends ConsumerState<AddReportScreen> {
  XFile? _imageFile;
  String? _selectedType;
  final _doctorController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final List<String> _reportTypes = ["नुस्खा", "Lab रिपोर्ट", "X-Ray", "ECG", "अन्य"];

  @override
  void dispose() {
    _doctorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _showSourcePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('कैमरा / Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('गैलरी / Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/${const Uuid().v4()}.jpg';
    
    return await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    ).then((xFile) => xFile != null ? File(xFile.path) : null);
  }

  Future<void> _saveReport() async {
    if (_imageFile == null || _selectedType == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
    });

    try {
      final selectedMember = ref.read(selectedFamilyMemberProvider);
      final repo = ref.read(reportsRepoProvider);
      
      // 1. Compress
      setState(() => _uploadProgress = 0.3);
      final compressedFile = await _compressImage(File(_imageFile!.path));
      if (compressedFile == null) throw Exception("Compression failed");

      // 2. Persist the image to permanent local storage.
      // There is no real cloud upload yet, so the local copy is the source of
      // truth. Previously the "online" branch stored a fake Firebase URL and
      // discarded the file, which made reports fail to open. The compressed
      // file lives in the temp dir (which the OS can clear), so always copy it
      // into the app documents directory. Drive backup uploads this local_path.
      if (mounted) setState(() => _uploadProgress = 0.6);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'report_${const Uuid().v4()}.jpg';
      final savedFile = await compressedFile.copy('${appDir.path}/$fileName');
      final finalPath = savedFile.path;

      // 3. Save to Repo
      if (mounted) setState(() => _uploadProgress = 0.9);
      final report = MedicalReport(
        id: const Uuid().v4(),
        memberId: selectedMember?.id ?? '1',
        type: _selectedType!,
        doctorName: _doctorController.text.isNotEmpty ? _doctorController.text : 'Unknown Doctor',
        date: _selectedDate,
        imagePath: finalPath,
      );

      await repo.addReport(report);

      if (mounted) setState(() => _uploadProgress = 1.0);
      
      if (mounted) {
        showSuccessSnackBar(context, 'रिपोर्ट सहेजी गई / Report Saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('रिपोर्ट जोड़ें / Add Report'),
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
              // Upload Zone or Preview
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _imageFile == null
                    ? _buildUploadZone(colorScheme)
                    : _buildImagePreview(colorScheme),
              ),

              const SizedBox(height: 24),

              // Form fields
              DropdownMenu<String>(
                label: const Text('रिपोर्ट का प्रकार * (Report Type)'),
                expandedInsets: EdgeInsets.zero,
                onSelected: (val) => setState(() => _selectedType = val),
                dropdownMenuEntries: _reportTypes.map((t) => DropdownMenuEntry(value: t, label: t)).toList(),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _doctorController,
                decoration: const InputDecoration(
                  labelText: 'डॉक्टर का नाम (Doctor Name)',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  hintText: 'वैकल्पिक',
                ),
              ),

              const SizedBox(height: 16),

              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                onTap: _pickDate,
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'नोट्स (Notes)',
                  hintText: 'वैकल्पिक (Optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 32),

              if (_isUploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    const Text('सहेजा जा रहा है... / Saving...', style: TextStyle(fontSize: 12)),
                  ],
                )
              else
                FilledButton(
                  onPressed: (_imageFile != null && _selectedType != null) ? _saveReport : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('रिपोर्ट सहेजें / Save Report'),
                ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadZone(ColorScheme colorScheme) {
    return GestureDetector(
      onLongPress: () {}, // For accessibility
      onTap: _showSourcePicker,
      child: CustomPaint(
        painter: DashedBorderPainter(color: colorScheme.primary),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 48, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text('फोटो या गैलरी से जोड़ें', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              Text('Camera or Gallery', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ColorScheme colorScheme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_imageFile!.path),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: FilledButton.tonal(
            onPressed: _showSourcePicker,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 4),
                Text('बदलें (Change)'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2,
    this.dashWidth = 8,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
