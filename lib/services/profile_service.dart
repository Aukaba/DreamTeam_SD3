import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a user's profile and personal information stored in `public.profiles`.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.phoneNumber,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    String? fallbackEmail,
    String? fallbackFullName,
    String? fallbackAvatarUrl,
  }) {
    final rawEmail = (json['email'] as String?)?.trim();
    final resolvedEmail = (rawEmail != null && rawEmail.isNotEmpty)
        ? rawEmail
        : (fallbackEmail?.trim() ?? '');

    final rawName = (json['full_name'] as String?)?.trim();
    final resolvedName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (fallbackFullName?.trim() ?? '');

    final rawAvatar = (json['avatar_url'] as String?)?.trim();
    final resolvedAvatar = (rawAvatar != null && rawAvatar.isNotEmpty)
        ? rawAvatar
        : ((fallbackAvatarUrl != null && fallbackAvatarUrl.trim().isNotEmpty)
            ? fallbackAvatarUrl.trim()
            : null);

    String? cleanOptional(dynamic val) {
      if (val == null) return null;
      final trimmed = val.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: resolvedEmail,
      fullName: resolvedName,
      username: cleanOptional(json['username']),
      avatarUrl: resolvedAvatar,
      phoneNumber: cleanOptional(json['phone_number']),
      address: cleanOptional(json['address']),
      emergencyContactName: cleanOptional(json['emergency_contact_name']),
      emergencyContactPhone: cleanOptional(json['emergency_contact_phone']),
      role: cleanOptional(json['role']) ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'username': username,
      'avatar_url': avatarUrl,
      'phone_number': phoneNumber,
      'address': address,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'role': role,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? username,
    bool clearUsername = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? phoneNumber,
    bool clearPhoneNumber = false,
    String? address,
    bool clearAddress = false,
    String? emergencyContactName,
    bool clearEmergencyContactName = false,
    String? emergencyContactPhone,
    bool clearEmergencyContactPhone = false,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: clearUsername ? null : (username ?? this.username),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      phoneNumber: clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
      address: clearAddress ? null : (address ?? this.address),
      emergencyContactName: clearEmergencyContactName
          ? null
          : (emergencyContactName ?? this.emergencyContactName),
      emergencyContactPhone: clearEmergencyContactPhone
          ? null
          : (emergencyContactPhone ?? this.emergencyContactPhone),
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Display-ready name with sensible fallback when `fullName` is empty.
  String get displayName {
    final trimmed = fullName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (email.trim().isNotEmpty) {
      return email.trim().split('@').first;
    }
    return 'SafeRoute User';
  }

  /// Up to 2 uppercase initials derived from [displayName].
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Returns `@username` if a username is set, otherwise `null`.
  String? get formattedUsername {
    final raw = username?.trim();
    if (raw == null || raw.isEmpty) return null;
    final clean = raw.startsWith('@') ? raw.substring(1).trim() : raw;
    return clean.isEmpty ? null : '@$clean';
  }

  /// Display-ready location string with Cebu City fallback.
  String get displayLocation {
    final raw = address?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Cebu City, Philippines';
  }
}

/// Result returned after updating a user's personal information.
class ProfileUpdateResult {
  final UserProfile profile;
  final bool emailConfirmationSent;

  const ProfileUpdateResult({
    required this.profile,
    this.emailConfirmationSent = false,
  });
}

/// Service handling profile retrieval, personal information updates, and avatar uploads.
class ProfileService {
  static const String avatarBucket = 'avatars';
  static const int maxAvatarBytes = 5 * 1024 * 1024; // 5 MB

  final SupabaseClient? _client;

  ProfileService({SupabaseClient? client}) : _client = client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the signed-in user's profile, creating a default record if missing.
  Future<UserProfile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final metaName = user.userMetadata?['full_name']?.toString();
    final metaAvatar = user.userMetadata?['avatar_url']?.toString();

    final existing = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) {
      return UserProfile.fromJson(
        existing,
        fallbackEmail: user.email,
        fallbackFullName: metaName,
        fallbackAvatarUrl: metaAvatar,
      );
    }

    // Backfill profile record if missing for this authenticated user
    final defaultName = (metaName != null && metaName.trim().isNotEmpty)
        ? metaName.trim()
        : (user.email?.split('@').first ?? 'User');

    final inserted = await client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'email': user.email ?? '',
            'full_name': defaultName,
            'avatar_url': metaAvatar,
            'role': 'user',
          },
          onConflict: 'id',
        )
        .select()
        .single();

    return UserProfile.fromJson(
      inserted,
      fallbackEmail: user.email,
      fallbackFullName: defaultName,
      fallbackAvatarUrl: metaAvatar,
    );
  }

  /// Update personal information fields in `public.profiles` and sync with Supabase Auth.
  Future<ProfileUpdateResult> updateProfile({
    required String fullName,
    required String email,
    String? username,
    String? phoneNumber,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('You must be signed in to update your profile.');
    }

    final cleanName = fullName.trim();
    final cleanEmail = email.trim();
    if (cleanName.isEmpty) {
      throw Exception('Full name cannot be empty.');
    }
    if (cleanEmail.isEmpty) {
      throw Exception('Email address cannot be empty.');
    }

    String? normalizeOptional(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    String? cleanUsername = normalizeOptional(username);
    if (cleanUsername != null && cleanUsername.startsWith('@')) {
      cleanUsername = cleanUsername.substring(1).trim();
      if (cleanUsername.isEmpty) cleanUsername = null;
    }

    final currentAuthEmail = (user.email ?? '').trim();
    final pendingAuthEmail = (user.newEmail ?? '').trim();

    String existingDbEmail = '';
    try {
      final existingRow = await client
          .from('profiles')
          .select('email')
          .eq('id', user.id)
          .maybeSingle();
      existingDbEmail = (existingRow?['email'] as String?)?.trim() ?? '';
    } catch (_) {}

    final lowerCleanEmail = cleanEmail.toLowerCase();
    final emailChanged = lowerCleanEmail != currentAuthEmail.toLowerCase() &&
        lowerCleanEmail != pendingAuthEmail.toLowerCase() &&
        lowerCleanEmail != existingDbEmail.toLowerCase();

    if (emailChanged) {
      await client.auth.updateUser(
        UserAttributes(
          email: cleanEmail,
          data: {'full_name': cleanName},
        ),
      );
    } else {
      try {
        await client.auth.updateUser(
          UserAttributes(
            data: {'full_name': cleanName},
          ),
        );
      } catch (_) {
        // Non-fatal metadata sync fallback
      }
    }

    final payload = {
      'id': user.id,
      'full_name': cleanName,
      'email': cleanEmail,
      'username': cleanUsername,
      'phone_number': normalizeOptional(phoneNumber),
      'address': normalizeOptional(address),
      'emergency_contact_name': normalizeOptional(emergencyContactName),
      'emergency_contact_phone': normalizeOptional(emergencyContactPhone),
    };

    final updated = await client
        .from('profiles')
        .upsert(payload, onConflict: 'id')
        .select()
        .single();

    return ProfileUpdateResult(
      profile: UserProfile.fromJson(
        updated,
        fallbackEmail: cleanEmail,
        fallbackFullName: cleanName,
      ),
      emailConfirmationSent: emailChanged,
    );
  }

  /// Upload a profile picture binary to Supabase Storage (`avatars` bucket)
  /// and save the public URL to `public.profiles.avatar_url`.
  Future<UserProfile> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('You must be signed in to update your profile picture.');
    }
    if (bytes.isEmpty) {
      throw Exception('Selected image file is empty.');
    }
    if (bytes.lengthInBytes > maxAvatarBytes) {
      throw Exception('Profile picture must be smaller than 5 MB.');
    }

    final ext = detectImageExtension(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
    final contentType = _mimeTypeForExtension(ext);
    final storagePath = '${user.id}/avatar.$ext';

    await client.storage.from(avatarBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final rawPublicUrl =
        client.storage.from(avatarBucket).getPublicUrl(storagePath);
    final versionedUrl =
        '$rawPublicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    try {
      await client.auth.updateUser(
        UserAttributes(data: {'avatar_url': versionedUrl}),
      );
    } catch (_) {
      // Non-fatal metadata sync
    }

    final updated = await client
        .from('profiles')
        .update({'avatar_url': versionedUrl})
        .eq('id', user.id)
        .select()
        .maybeSingle();

    if (updated != null) {
      return UserProfile.fromJson(
        updated,
        fallbackEmail: user.email,
        fallbackAvatarUrl: versionedUrl,
      );
    }

    // Fallback if profile row hadn't been created yet
    final created = await client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'email': user.email ?? '',
            'full_name': user.userMetadata?['full_name']?.toString() ??
                (user.email?.split('@').first ?? 'User'),
            'avatar_url': versionedUrl,
            'role': 'user',
          },
          onConflict: 'id',
        )
        .select()
        .single();

    return UserProfile.fromJson(
      created,
      fallbackEmail: user.email,
      fallbackAvatarUrl: versionedUrl,
    );
  }

  /// Remove the user's profile picture from Storage and clear `avatar_url`.
  Future<UserProfile> removeAvatar() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('You must be signed in to remove your profile picture.');
    }

    try {
      final files =
          await client.storage.from(avatarBucket).list(path: user.id);
      if (files.isNotEmpty) {
        final paths = files.map((f) => '${user.id}/${f.name}').toList();
        await client.storage.from(avatarBucket).remove(paths);
      }
    } catch (_) {
      // Best-effort storage cleanup; still clear DB reference below
    }

    try {
      await client.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );
    } catch (_) {}

    final updated = await client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', user.id)
        .select()
        .maybeSingle();

    if (updated != null) {
      return UserProfile.fromJson(
        updated,
        fallbackEmail: user.email,
      ).copyWith(clearAvatarUrl: true);
    }

    final current = await getProfile();
    if (current != null) {
      return current.copyWith(clearAvatarUrl: true);
    }

    throw Exception('Unable to update profile record.');
  }

  /// Detects a supported image extension (`jpg`, `png`, `webp`, `gif`) from
  /// [mimeType], [fileName], or [bytes] magic header bytes.
  static String detectImageExtension({
    required String fileName,
    String? mimeType,
    Uint8List? bytes,
  }) {
    final cleanMime = mimeType?.trim().toLowerCase() ?? '';
    if (cleanMime == 'image/png') return 'png';
    if (cleanMime == 'image/webp') return 'webp';
    if (cleanMime == 'image/gif') return 'gif';
    if (cleanMime == 'image/jpeg' || cleanMime == 'image/jpg') return 'jpg';

    final cleaned = fileName.trim().toLowerCase().split('?').first;
    final dotIndex = cleaned.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < cleaned.length - 1) {
      final ext = cleaned.substring(dotIndex + 1);
      if (const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext)) {
        return ext == 'jpeg' ? 'jpg' : ext;
      }
    }

    if (bytes != null && bytes.length >= 4) {
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      // GIF: 47 49 46 38 ("GIF8")
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        return 'gif';
      }
      // WEBP: "RIFF" .... "WEBP"
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
    }

    return 'jpg';
  }

  static String _mimeTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
