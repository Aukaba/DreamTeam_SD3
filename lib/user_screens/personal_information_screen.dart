import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Authentication/auth_error_handler.dart';
import '../services/profile_service.dart';
import '../widgets/camera_capture_screen.dart';
import '../widgets/interactive_location_picker.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _lightBlue = Color(0xFFEFF5FB);
const Color _accentBlue = Color(0xFF7098C2);
const Color _inputFill = Color(0xFFF3F5F9);
const Color _alertRed = Color(0xFFE53935);
const Color _successGreen = Color(0xFF10B981);

class PersonalInformationScreen extends StatefulWidget {
  final ProfileService? service;
  final UserProfile? initialProfile;
  final ImagePicker? imagePicker;

  const PersonalInformationScreen({
    super.key,
    this.service,
    this.initialProfile,
    this.imagePicker,
  });

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final ProfileService _service;
  late final ImagePicker _picker;

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  UserProfile? _profile;
  Uint8List? _pendingAvatarBytes;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _userHasEditedForm = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProfileService();
    _picker = widget.imagePicker ?? ImagePicker();

    if (widget.initialProfile != null) {
      _applyProfileToControllers(widget.initialProfile!);
      _isLoading = false;
      // Refresh in background to ensure freshest DB values
      _refreshProfileSilently();
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _applyProfileToControllers(UserProfile profile) {
    _profile = profile;
    _fullNameController.text = profile.fullName;
    _usernameController.text = profile.username ?? '';
    _emailController.text = profile.email;
    _phoneController.text = profile.phoneNumber ?? '';
    _addressController.text = profile.address ?? '';
    _emergencyNameController.text = profile.emergencyContactName ?? '';
    _emergencyPhoneController.text = profile.emergencyContactPhone ?? '';
  }

  Future<void> _refreshProfileSilently() async {
    try {
      final fetched = await _service.getProfile();
      if (!mounted || fetched == null || _isSaving || _isUploadingAvatar) {
        return;
      }
      setState(() {
        if (_userHasEditedForm) {
          _profile = fetched.copyWith(
            avatarUrl: _profile?.avatarUrl ?? fetched.avatarUrl,
          );
        } else {
          _applyProfileToControllers(fetched);
        }
      });
    } catch (_) {
      // Keep initialProfile displayed if background refresh fails
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final fetched = await _service.getProfile();
      if (!mounted) return;
      if (fetched == null) {
        setState(() {
          _loadError = 'Please sign in to view your personal information.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _applyProfileToControllers(fetched);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is StorageException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Failed to upload profile photo. Please try again.';
    }
    if (error is AuthException || error is PostgrestException) {
      return AuthErrorHandler.getErrorMessage(error);
    }
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return AuthErrorHandler.getErrorMessage(error);
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim().startsWith('@')
        ? value.trim().substring(1)
        : value.trim();
    if (raw.isEmpty) return null;
    if (raw.length < 2 || raw.length > 30) {
      return 'Username must be between 2 and 30 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(raw)) {
      return 'Only letters, numbers, dots, and underscores allowed';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number (7–15 digits)';
    }
    if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(trimmed)) {
      return 'Phone number contains invalid characters';
    }
    return null;
  }

  void _showPhotoOptionsSheet() {
    if (_isUploadingAvatar) return;
    final hasAvatar =
        _profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: _lightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: _primaryNavy,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: _primaryNavy,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Take a Photo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadPhoto(ImageSource.camera);
                    },
                  ),
                if (hasAvatar)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: _alertRed,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Remove Current Photo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _alertRed,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      XFile? picked;
      if (source == ImageSource.camera &&
          (widget.imagePicker == null || widget.imagePicker is! ImagePicker)) {
        final result = await Navigator.of(context).push<CameraCaptureResult>(
          MaterialPageRoute(
            builder: (ctx) => const CameraCaptureScreen(),
            fullscreenDialog: true,
          ),
        );
        if (!mounted || result == null) return;
        if (result.openGallery) {
          picked = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
        } else {
          picked = result.file;
        }
      } else {
        picked = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
      }
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pendingAvatarBytes = bytes;
        _isUploadingAvatar = true;
        _saveError = null;
      });

      final updatedProfile = await _service.uploadAvatar(
        bytes: bytes,
        fileName: picked.name.isNotEmpty ? picked.name : picked.path,
        mimeType: picked.mimeType,
      );

      if (!mounted) return;
      setState(() {
        _profile = (_profile ?? updatedProfile).copyWith(
          avatarUrl: updatedProfile.avatarUrl,
        );
        _pendingAvatarBytes = null;
        _isUploadingAvatar = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingAvatarBytes = null;
        _isUploadingAvatar = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isUploadingAvatar = true;
      _saveError = null;
    });

    try {
      final updatedProfile = await _service.removeAvatar();
      if (!mounted) return;
      setState(() {
        _profile = (_profile ?? updatedProfile).copyWith(clearAvatarUrl: true);
        _pendingAvatarBytes = null;
        _isUploadingAvatar = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture removed.'),
          backgroundColor: _primaryNavy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAddressMapPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pickerContext) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'Select Your Location',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _primaryNavy,
              ),
            ),
            backgroundColor: Colors.white,
            foregroundColor: _primaryNavy,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(pickerContext),
            ),
          ),
          body: InteractiveLocationPicker(
            onLocationConfirmed: (_, address) {
              Navigator.pop(pickerContext);
              if (mounted) {
                setState(() {
                  _userHasEditedForm = true;
                  _addressController.text = address;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _savePersonalInformation() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final result = await _service.updateProfile(
        fullName: _fullNameController.text,
        email: _emailController.text,
        username: _usernameController.text,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
      );

      if (!mounted) return;
      setState(() {
        _profile = result.profile;
        _isSaving = false;
      });

      final message = result.emailConfirmationSent
          ? 'Personal information saved! Please check your inbox to verify your new email address.'
          : 'Personal information updated successfully!';

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      nav.pop(_profile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveError = _friendlyError(e);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_profile);
      },
      child: Scaffold(
        backgroundColor: _bgBeige,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _primaryNavy,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_profile),
          ),
          title: const Text(
            'Personal Information',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: const Color(0xFFEDF0F5),
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryNavy),
      );
    }

    if (_loadError != null && _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: _alertRed,
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: _primaryNavy,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Form(
        key: _formKey,
        onChanged: () {
          _userHasEditedForm = true;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Profile Picture Card
            _buildAvatarCard(),

            const SizedBox(height: 24),

            // 2. Basic Information Section
            _buildSectionLabel('BASIC INFORMATION'),
            _buildCardGroup(
              children: [
                _buildInputField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: AuthErrorHandler.validateFullName,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _usernameController,
                  label: 'Username (Optional)',
                  hintText: 'e.g. juan_delacruz',
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: _validateUsername,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Contact Details Section
            _buildSectionLabel('CONTACT DETAILS'),
            _buildCardGroup(
              children: [
                _buildInputField(
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'Enter your email address',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: AuthErrorHandler.validateEmail,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hintText: 'e.g. +63 912 345 6789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _addressController,
                  label: 'Home / City Address',
                  hintText: 'e.g. Cebu City, Philippines',
                  prefixIcon: Icons.location_on_outlined,
                  suffixIcon: IconButton(
                    tooltip: 'Pick location on map',
                    icon: const Icon(
                      Icons.map_outlined,
                      color: _accentBlue,
                      size: 20,
                    ),
                    onPressed: _openAddressMapPicker,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. Emergency Contact Section
            _buildSectionLabel('EMERGENCY CONTACT'),
            _buildCardGroup(
              children: [
                _buildInputField(
                  controller: _emergencyNameController,
                  label: 'Emergency Contact Name',
                  hintText: 'Full name of emergency contact',
                  prefixIcon: Icons.shield_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _emergencyPhoneController,
                  label: 'Emergency Contact Number',
                  hintText: 'e.g. +63 917 000 0000',
                  prefixIcon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
              ],
            ),

            if (_saveError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _saveError!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // 5. Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSaving || _isUploadingAvatar)
                    ? null
                    : _savePersonalInformation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _primaryNavy.withValues(alpha: 0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCard() {
    final avatarUrl = _profile?.avatarUrl;
    final initials = _profile?.initials ?? 'U';

    Widget avatarContent;
    if (_pendingAvatarBytes != null) {
      avatarContent = Image.memory(
        _pendingAvatarBytes!,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = Image.network(
        avatarUrl,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialsAvatar(initials),
      );
    } else {
      avatarContent = _buildInitialsAvatar(initials);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            key: const Key('personal_info_avatar_tap'),
            onTap: _showPhotoOptionsSheet,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: _lightBlue,
                  child: ClipOval(child: avatarContent),
                ),
                if (_isUploadingAvatar)
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _primaryNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isUploadingAvatar ? null : _showPhotoOptionsSheet,
            icon: const Icon(Icons.photo_camera_outlined, size: 17),
            label: Text(
              _isUploadingAvatar ? 'Uploading photo...' : 'Change Profile Photo',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _primaryNavy,
              backgroundColor: _lightBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      width: 92,
      height: 92,
      color: _lightBlue,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _primaryNavy,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: _secondaryGrey,
        ),
      ),
    );
  }

  Widget _buildCardGroup({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _primaryNavy,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _secondaryGrey,
            ),
            prefixIcon: Icon(
              prefixIcon,
              size: 19,
              color: _accentBlue,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryNavy, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _alertRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _alertRed, width: 1.4),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: _alertRed,
            ),
          ),
        ),
      ],
    );
  }
}
