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
          message:
              'Your session changed while verifying permissions. Please try again.',
        );
      }

      dynamic rpcResponse = await supabase.rpc('get_my_role');
      String? role = rpcResponse is String ? rpcResponse.trim() : null;

      // If a legacy auth account has no profile row yet, insert a default 'user' row once
      // and re-verify via the server RPC.
      if (role == null) {
        final existingProfile = await supabase
            .from('profiles')
            .select('id')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (existingProfile == null) {
          try {
            final email = currentUser.email ?? '';
            await supabase.from('profiles').insert({
              'id': currentUser.id,
              'email': email.isNotEmpty ? email : null,
              'full_name':
                  currentUser.userMetadata?['full_name']?.toString() ??
                      (email.contains('@') ? email.split('@').first : 'User'),
              'role': 'user',
            });
            rpcResponse = await supabase.rpc('get_my_role');
            role = rpcResponse is String ? rpcResponse.trim() : null;
          } catch (e) {
            debugPrint('Legacy profile backfill skipped: $e');
          }
        }
      }

      if (role == 'admin') {
        return const UserRoleResolution.admin();
      }
      if (role == 'user') {
        return const UserRoleResolution.user();
      }

      return UserRoleResolution(
        status: UserRoleStatus.unauthorized,
        role: role,
        message:
            'Access denied. Your account does not have a valid role assigned.',
      );
    } catch (e) {
      debugPrint('Error verifying user role via server RPC: $e');
      return const UserRoleResolution(
        status: UserRoleStatus.error,
        message:
            'Unable to verify your account permissions. Please check your connection and try again.',
      );
    }
  }
}
