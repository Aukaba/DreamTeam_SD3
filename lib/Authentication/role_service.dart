import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRoleStatus {
  admin,
  user,
  unauthorized,
  error,
}

class UserRoleResolution {
  final UserRoleStatus status;
  final String? role;
  final String? message;

  const UserRoleResolution({
    required this.status,
    this.role,
    this.message,
  });

  const UserRoleResolution.admin()
      : status = UserRoleStatus.admin,
        role = 'admin',
        message = null;

  const UserRoleResolution.user()
      : status = UserRoleStatus.user,
        role = 'user',
        message = null;
}

class UserRoleService {
  const UserRoleService._();

  /// Resolves the authenticated user's role using the trusted server-side
  /// `get_my_role` RPC (backed by RLS/trigger-locked `profiles.role` and
  /// server-only `auth.users.raw_app_meta_data`).
  static Future<UserRoleResolution> resolveUserRole(
    SupabaseClient supabase, {
    required String expectedUserId,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != expectedUserId) {
        return const UserRoleResolution(
          status: UserRoleStatus.error,
          message: 'Your session changed while verifying permissions. Please try again.',
        );
      }

      final dynamic rpcResponse = await supabase.rpc('get_my_role');
      final String? role = rpcResponse is String ? rpcResponse.trim() : null;

      if (role == 'admin') {
        return const UserRoleResolution.admin();
      }
      if (role == 'user') {
        return const UserRoleResolution.user();
      }

      return UserRoleResolution(
        status: UserRoleStatus.unauthorized,
        role: role,
        message: 'Access denied. Your account does not have a valid role assigned.',
      );
    } catch (e) {
      debugPrint('Error verifying user role via server RPC: $e');
      return const UserRoleResolution(
        status: UserRoleStatus.error,
        message: 'Unable to verify your account permissions. Please check your connection and try again.',
      );
    }
  }
}

