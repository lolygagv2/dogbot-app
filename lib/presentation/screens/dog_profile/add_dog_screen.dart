import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
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
        title: Text(context.l10n.addDogTitle),
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
                // The screen's ONE gold element: the final "Save Dog" CTA
                // (Continue on earlier steps stays the quiet primary).
                FilledButton(
                  style: isLastStep ? WimzTheme.goldButtonStyle(context) : null,
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? context.l10n.addDogSaveDog : context.l10n.addDogContinue),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(context.l10n.back),
                  ),
              ],
            ),
          );
        },
        steps: [
          // Step 1: Name
          Step(
            title: Text(context.l10n.dogNameLabel),
            subtitle: _nameController.text.isNotEmpty
                ? Text(_nameController.text)
                : null,
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildNameStep(),
          ),

          // Step 2: Color
          Step(
            title: Text(context.l10n.addDogStepColor),
            subtitle: Text(_selectedColor.localizedLabel(context.l10n)),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildColorStep(),
          ),

          // Step 3: Photo
          Step(
            title: Text(context.l10n.addDogStepPhoto),
            subtitle: _photoPath != null
                ? Text(context.l10n.addDogPhotoSelected)
                : Text(context.l10n.addDogOptional),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildPhotoStep(),
          ),

          // Step 4: ARUCO (Optional)
          Step(
            title: Text(context.l10n.addDogStepAruco),
            subtitle: Text(context.l10n.addDogOptional),
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
          Text(
            context.l10n.addDogNameQuestion,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.addDogNameFieldLabel,
              hintText: context.l10n.addDogNameHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.pets),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.addDogNameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.addDogBreedQuestion,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _breedController,
            decoration: InputDecoration(
              labelText: context.l10n.dogBreedLabel,
              hintText: context.l10n.addDogBreedHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.category),
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
        Text(
          context.l10n.addDogColorQuestion,
          style: const TextStyle(fontSize: 16),
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
                        color: _getColorPreview(context.wimz, color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.wimz.lineStrong,
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      color.localizedLabel(context.l10n),
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
        Text(
          context.l10n.addDogPhotoPrompt,
          style: const TextStyle(fontSize: 16),
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
                          context.l10n.addDogTapToAdd,
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
              label: Text(context.l10n.addDogCamera),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: Text(context.l10n.addDogGallery),
            ),
          ],
        ),

        if (_photoPath != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _photoPath = null),
              child: Text(context.l10n.addDogRemovePhoto),
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
        Text(
          context.l10n.addDogArucoIntro,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.addDogArucoAutoPicked,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _arucoController,
          decoration: InputDecoration(
            labelText: context.l10n.addDogArucoIdLabel,
            hintText: context.l10n.addDogArucoIdHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.qr_code_2),
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
              label: Text(context.l10n.arucoPrintMarker),
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
                  context.l10n.addDogArucoSkipHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
          SnackBar(
            content: Text(context.l10n.addDogMarkerBundleMissing),
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

  /// Coat swatch from the brand tokens; the enum label is always shown
  /// next to the swatch, so colour never carries the choice alone.
  Color _getColorPreview(WimzColors w, DogColor color) {
    switch (color) {
      case DogColor.black:
        return w.brandInk;
      case DogColor.yellow:
        return w.goldDeep;
      case DogColor.brown:
        return w.inkMuted;
      case DogColor.white:
        return w.brandWhite;
      case DogColor.mixed:
        return w.lineStrong;
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
              title: Text(context.l10n.dogPhotoTakePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.dogPhotoChooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.error),
                title: Text(context.l10n.dogPhotoRemovePhoto,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
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
          SnackBar(content: Text(context.l10n.addDogPickImageFailed('$e'))),
        );
      }
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      // Validate name
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.addDogNameRequired)),
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
        SnackBar(content: Text(context.l10n.addDogNameRequired)),
      );
      return;
    }

    final breed = _breedController.text.trim();
    final profile = DogProfile(
      // WIMZ_Data_Architecture_Spec §4: dog_id is UUIDv7, never recycled —
      // time-orderable and collision-free across devices, which matters when
      // edge rows merge into the cloud corpus. (Legacy dogs keep their old
      // 'dog_<epochms>' ids; the id is opaque TEXT everywhere.)
      id: const Uuid().v7(),
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
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: cs.onError),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.addDogDuplicateName(name),
                    style: TextStyle(color: cs.onError),
                  ),
                ),
              ],
            ),
            backgroundColor: cs.error,
          ),
        );
      }
      return;
    }

    // Select the new dog
    ref.read(selectedDogProvider.notifier).selectDog(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addDogRobotWillRecognize(profile.name))),
      );
      context.pop();
    }
  }
}
