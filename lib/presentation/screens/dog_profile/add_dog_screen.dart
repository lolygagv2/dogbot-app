import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../widgets/aruco_marker_view.dart';

/// Add Dog screen with stepper flow
class AddDogScreen extends ConsumerStatefulWidget {
  final int? initialArucoId;

  const AddDogScreen({super.key, this.initialArucoId});

  @override
  ConsumerState<AddDogScreen> createState() => _AddDogScreenState();
}

class _AddDogScreenState extends ConsumerState<AddDogScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form data
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  DogColor _selectedColor = DogColor.mixed;
  String? _photoPath;
  final _arucoController = TextEditingController();
  // Build 94: true once we've auto-populated the ArUco field, so we don't
  // overwrite the user's manual edits if they back-step into step 3 again.
  bool _arucoAutofilled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialArucoId != null) {
      _arucoController.text = widget.initialArucoId.toString();
      _arucoAutofilled = true;
    }
  }

  /// Build 94: assign the next free DICT_4X4_1000 ID when the user first
  /// reaches the ArUco step. Idempotent — only fills if the field is still
  /// empty and the user hasn't touched it.
  void _maybeAutofillAruco() {
    if (_arucoAutofilled) return;
    if (_arucoController.text.isNotEmpty) return;
    final id = ref.read(dogProfilesProvider.notifier).nextFreeArucoId();
    _arucoController.text = id.toString();
    _arucoAutofilled = true;
  }

  int? get _currentArucoId => int.tryParse(_arucoController.text.trim());

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _arucoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Dog'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        onStepTapped: (step) {
          if (step < _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 3;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? 'Save Dog' : 'Continue'),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        steps: [
          // Step 1: Name
          Step(
            title: const Text('Name'),
            subtitle: _nameController.text.isNotEmpty
                ? Text(_nameController.text)
                : null,
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildNameStep(),
          ),

          // Step 2: Color
          Step(
            title: const Text('Color'),
            subtitle: Text(_selectedColor.label),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildColorStep(),
          ),

          // Step 3: Photo
          Step(
            title: const Text('Photo'),
            subtitle: _photoPath != null
                ? const Text('Photo selected')
                : const Text('Optional'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildPhotoStep(),
          ),

          // Step 4: ARUCO (Optional)
          Step(
            title: const Text('ARUCO Tag'),
            subtitle: const Text('Optional'),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
            content: _buildArucoStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What's your dog's name?",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Dog Name',
              hintText: 'e.g., Max, Luna, Buddy',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pets),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "What breed is your dog?",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _breedController,
            decoration: const InputDecoration(
              labelText: 'Breed',
              hintText: 'e.g., Golden Retriever, Mixed, Unknown',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _buildColorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What's your dog's primary coat color?",
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: DogColor.values.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getColorPreview(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      color.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add a profile photo for your dog',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),

        // Photo preview
        Center(
          child: GestureDetector(
            onTap: _showPhotoOptions,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
              child: _photoPath != null
                  ? ClipOval(
                      child: Image.file(
                        File(_photoPath!),
                        fit: BoxFit.cover,
                        width: 150,
                        height: 150,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Photo options buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ],
        ),

        if (_photoPath != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _photoPath = null),
              child: const Text('Remove photo'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArucoStep() {
    final markerId = _currentArucoId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WIM-Z uses an ARUCO marker on your dog\'s collar to tell them apart.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'We picked the next free ID for you. Print this marker and attach it to the collar.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _arucoController,
          decoration: const InputDecoration(
            labelText: 'ARUCO Marker ID',
            hintText: 'e.g., 42',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code_2),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}), // refresh marker preview
        ),
        const SizedBox(height: 16),
        if (markerId != null && markerId >= 0 && markerId <= 999) ...[
          Center(child: ArucoMarkerView(markerId: markerId, size: 200)),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _printMarker(markerId, _nameController.text.trim()),
              icon: const Icon(Icons.print),
              label: const Text('Print marker'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can clear this field to skip ArUco — useful if you only have one dog or prefer appearance-based ID.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _printMarker(int markerId, String dogName) async {
    final bytes = await loadArucoMarkerBytes(markerId);
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Marker bundle not generated yet — run scripts/generate_aruco_markers.py',
            ),
          ),
        );
      }
      return;
    }

    final pdfImage = pw.MemoryImage(bytes);
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                dogName.isNotEmpty ? dogName : 'Dog',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('ARUCO DICT_4X4_1000 — ID $markerId',
                  style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 24),
              // 4 inches square — large enough for the robot's camera to lock
              // onto from across a typical room.
              pw.Container(
                width: 4 * PdfPageFormat.inch,
                height: 4 * PdfPageFormat.inch,
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'WIM-Z ArUco $markerId.pdf',
    );
  }

  Color _getColorPreview(DogColor color) {
    switch (color) {
      case DogColor.black:
        return const Color(0xFF333333);
      case DogColor.yellow:
        return const Color(0xFFD4A574);
      case DogColor.brown:
        return const Color(0xFF8B4513);
      case DogColor.white:
        return const Color(0xFFF5F5F5);
      case DogColor.mixed:
        return const Color(0xFF888888);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // Copy to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'dog_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = '${appDir.path}/$fileName';
        await File(image.path).copy(savedPath);

        setState(() => _photoPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      // Validate name
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name')),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      // Build 94: assign the next free ArUco ID when first advancing into
      // step 3, so the user sees a marker preview without having to type.
      if (_currentStep == 2) {
        _maybeAutofillAruco();
      }
      setState(() => _currentStep++);
    } else {
      _saveDog();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveDog() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    final breed = _breedController.text.trim();
    final profile = DogProfile(
      id: 'dog_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      breed: breed.isNotEmpty ? breed : null,
      color: _selectedColor,
      localPhotoPath: _photoPath,
      arucoMarkerId: _arucoController.text.isNotEmpty
          ? int.tryParse(_arucoController.text)
          : null,
      createdAt: DateTime.now(),
    );

    final added = await ref.read(dogProfilesProvider.notifier).addProfile(profile);

    if (!added) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A dog named "$name" already exists'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Select the new dog
    ref.read(selectedDogProvider.notifier).selectDog(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Robot will now recognize ${profile.name}')),
      );
      context.pop();
    }
  }
}
