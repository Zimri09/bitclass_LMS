import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/course_banner.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/course_repository.dart';
import '../bloc/course_bloc.dart';

/// Screen for instructors to create or edit a course
class CreateCourseScreen extends StatefulWidget {
  final String? courseId; // null = create new, non-null = edit existing

  const CreateCourseScreen({super.key, this.courseId});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = AppConstants.courseCategories.first;
  XFile? _selectedThumbnail;
  Uint8List? _thumbnailBytes;
  String? _selectedPresetId; // preset banner ID (e.g. 'blue-teal')
  String? _existingThumbnailUrl; // for edit mode — existing URL
  bool _isLoadingCourse = false;

  bool get _isEditMode => widget.courseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingCourse();
    }
  }

  Future<void> _loadExistingCourse() async {
    setState(() => _isLoadingCourse = true);
    try {
      final course = await context.read<CourseRepository>().getCourse(
        widget.courseId!,
      );
      if (course != null && mounted) {
        setState(() {
          _titleController.text = course.title;
          _descriptionController.text = course.description;
          _selectedCategory = course.category;
          _existingThumbnailUrl = course.thumbnailUrl;
          // Pre-select preset if editing a course with a preset banner
          if (CourseBannerPresets.isPreset(course.thumbnailUrl)) {
            _selectedPresetId = CourseBannerPresets.presetId(
              course.thumbnailUrl,
            );
          }
          _isLoadingCourse = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingCourse = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCourse = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load course: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Compute the effective thumbnailUrl to store.
  String? get _effectiveThumbnailUrl {
    // Custom uploaded image takes priority
    if (_selectedThumbnail != null) return _selectedThumbnail!.path;
    // Then a selected preset
    if (_selectedPresetId != null) {
      return CourseBannerPresets.toUrl(_selectedPresetId!);
    }
    // Preserve existing URL in edit mode
    return _existingThumbnailUrl;
  }

  void _handleCreateCourse() {
    if (_formKey.currentState!.validate()) {
      if (_isEditMode) {
        // Update existing course
        final updates = <String, dynamic>{
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
        };
        if (_effectiveThumbnailUrl != null) {
          updates['thumbnailUrl'] = _effectiveThumbnailUrl;
        }
        context.read<CourseBloc>().add(
          UpdateCourse(courseId: widget.courseId!, updates: updates),
        );
      } else {
        // Create new course
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          context.read<CourseBloc>().add(
            CreateCourse(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              category: _selectedCategory,
              instructorId: authState.user.id,
              instructorName: authState.user.displayNameOrEmail,
              thumbnailUrl: _effectiveThumbnailUrl,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedThumbnail = image;
          _thumbnailBytes = bytes;
          _selectedPresetId = null; // custom image overrides preset
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildBannerPreview() {
    // Custom uploaded image
    if (_thumbnailBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _thumbnailBytes!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: AppColors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() {
                  _selectedThumbnail = null;
                  _thumbnailBytes = null;
                }),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Preset banner
    if (_selectedPresetId != null) {
      return Stack(
        children: [
          CourseBannerWidget(
            thumbnailUrl: CourseBannerPresets.toUrl(_selectedPresetId!),
            width: double.infinity,
            height: 160,
            borderRadius: BorderRadius.circular(12),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: AppColors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _selectedPresetId = null),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                CourseBannerPresets.fromId(_selectedPresetId!)?.label ?? '',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Empty state
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            'Select a theme or upload an image',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetGrid() {
    final presets = CourseBannerPresets.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isSelected =
            _selectedPresetId == preset.id && _thumbnailBytes == null;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedPresetId = preset.id;
            _selectedThumbnail = null;
            _thumbnailBytes = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: preset.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 2.5 : 0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: preset.colors.first.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Icon(
                    preset.icon,
                    size: 32,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        preset.icon,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: preset.colors.first,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _isEditMode ? 'Edit Course' : 'Create Course',
          style: AppTextStyles.h3,
        ),
      ),
      body: _isLoadingCourse
          ? const Center(child: CircularProgressIndicator())
          : BlocListener<CourseBloc, CourseState>(
              listener: (context, state) {
                if (state is CourseCreated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Course created successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  // After creating a course, take instructor to file upload
                  // so they can immediately add course materials.
                  context.go(AppRoutes.uploadFilePath(state.course.id));
                } else if (state is CourseUpdated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Course updated successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.go(AppRoutes.courseDetailPath(state.course.id));
                } else if (state is CourseError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        GlowCard(
                          glowColor: AppColors.secondary,
                          glowIntensity: 0.1,
                          isHoverable: false,
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.add_box,
                                  color: AppColors.secondary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isEditMode
                                          ? 'Edit Course'
                                          : 'New Course',
                                      style: AppTextStyles.h3,
                                    ),
                                    Text(
                                      _isEditMode
                                          ? 'Update your course details'
                                          : 'Share your knowledge with students',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Course details form
                        Text('Course Details', style: AppTextStyles.h4),
                        const SizedBox(height: 16),

                        GlowCard(
                          glowColor: AppColors.primary,
                          glowIntensity: 0.05,
                          isHoverable: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Course Title',
                                  hintText:
                                      'e.g., Introduction to Python Programming',
                                  prefixIcon: Icon(Icons.title),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a course title';
                                  }
                                  if (value.length < 5) {
                                    return 'Title must be at least 5 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Category
                              Text('Category', style: AppTextStyles.label),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: AppConstants.courseCategories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCategory = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 20),

                              // Description
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                  labelText: 'Course Description',
                                  hintText:
                                      'Describe what students will learn in this course...',
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a course description';
                                  }
                                  if (value.length < 20) {
                                    return 'Description must be at least 20 characters';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Course Banner
                        Text('Course Banner', style: AppTextStyles.h4),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a preset theme or upload your own image',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Banner preview
                        _buildBannerPreview(),
                        const SizedBox(height: 16),

                        // Preset grid
                        Text('Themes', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        _buildPresetGrid(),
                        const SizedBox(height: 12),

                        // Upload button
                        OutlinedButton.icon(
                          onPressed: _pickThumbnail,
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload Custom Image'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Create button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    context.go(AppRoutes.myCourses),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: BlocBuilder<CourseBloc, CourseState>(
                                builder: (context, state) {
                                  final isLoading = state is CourseLoading;
                                  return ElevatedButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : _handleCreateCourse,
                                    icon: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    AppColors.background,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            _isEditMode
                                                ? Icons.save
                                                : Icons.add,
                                          ),
                                    label: Text(
                                      isLoading
                                          ? (_isEditMode
                                                ? 'Saving...'
                                                : 'Creating...')
                                          : (_isEditMode
                                                ? 'Save Changes'
                                                : 'Create Course'),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Note
                        Text(
                          'Note: Your course will be saved as a draft. You can add lessons and publish it later.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
