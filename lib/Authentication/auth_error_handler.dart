import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorHandler {
  /// Transforms any auth-related exception or error into a clear, user-friendly message.
  static String getErrorMessage(dynamic error) {
    if (error == null) {
      return 'An unexpected error occurred. Please try again.';
    }

    if (error is AuthException) {
      return _parseAuthException(error);
    }

    if (error is PostgrestException) {
      return 'Unable to process your account data. Please try again or contact support.';
    }

    final errorString = error.toString().toLowerCase();

    // Network & connection issues
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('clientexception') ||
        errorString.contains('network') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection closed') ||
        errorString.contains('handshakeexception')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    if (errorString.contains('timeoutexception') || errorString.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    }

    if (errorString.contains('invalid login credentials') ||
        errorString.contains('invalid_grant') ||
        errorString.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }

    if (errorString.contains('user already registered') ||
        errorString.contains('already registered') ||
        errorString.contains('user_already_exists')) {
      return 'An account with this email already exists. Please sign in or reset your password.';
    }

    if (errorString.contains('email not confirmed')) {
      return 'Please verify your email address before signing in. Check your inbox for the confirmation link.';
    }

    return 'Something went wrong. Please check your connection and try again.';
  }

  static String _parseAuthException(AuthException exception) {
    final message = exception.message.toLowerCase();
    final statusCode = exception.statusCode;

    // HTTP 429 or rate limits
    if (statusCode == '429' ||
        message.contains('rate limit') ||
        message.contains('over_email_send_rate_limit') ||
        message.contains('over_request_rate_limit') ||
        message.contains('too many requests')) {
      return 'Too many attempts. Please wait a few moments before trying again.';
    }

    if (message.contains('for security purposes') ||
        message.contains('security purposes, you can only request this once')) {
      return 'For security reasons, please wait a moment before requesting another reset link.';
    }

    // Invalid credentials
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials') ||
        message.contains('invalid_grant')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }

    // Email not confirmed
    if (message.contains('email not confirmed')) {
      return 'Please verify your email address before signing in. Check your inbox for the confirmation link.';
    }

    // Existing user
    if (message.contains('user already registered') ||
        message.contains('already registered') ||
        message.contains('user_already_exists')) {
      return 'An account with this email already exists. Please sign in or reset your password.';
    }

    // Password requirements
    if (message.contains('password should be at least') ||
        message.contains('weak_password') ||
        message.contains('password is too short')) {
      return 'Password must be at least 6 characters long.';
    }

    if (message.contains('same_password') ||
        message.contains('new password should be different') ||
        message.contains('different from the old')) {
      return 'Your new password must be different from your old password.';
    }

    // Invalid email format
    if (message.contains('unable to validate email') ||
        message.contains('invalid email') ||
        message.contains('email address: invalid format')) {
      return 'Please enter a valid email address.';
    }

    // User not found
    if (message.contains('user not found') || message.contains('user_not_found')) {
      return 'No account was found with this email address.';
    }

    // Token expired / invalid
    if (message.contains('token has expired') ||
        message.contains('email link is invalid or has expired') ||
        message.contains('token is invalid') ||
        message.contains('otp_expired')) {
      return 'This verification or reset link has expired or is invalid. Please request a new one.';
    }

    // Disabled signups
    if (message.contains('signup is disabled') ||
        message.contains('signups not allowed')) {
      return 'New user registrations are currently disabled. Please contact support.';
    }

    // Session missing
    if (message.contains('auth session missing') || message.contains('session_not_found')) {
      return 'Your session has expired. Please sign in again.';
    }

    // Network
    if (message.contains('network') ||
        message.contains('failed host lookup') ||
        message.contains('socket')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    // Fallback: If message contains technical jargon, give a clean friendly message
    if (message.contains('{') ||
        message.contains('status code') ||
        message.contains('gotrue') ||
        message.contains('exception') ||
        message.contains('sub claim')) {
      return 'Authentication failed. Please verify your information and try again.';
    }

    // If it's already an understandable sentence, capitalize the first letter and ensure proper punctuation
    if (exception.message.isNotEmpty) {
      final text = exception.message.trim();
      final capitalized = text[0].toUpperCase() + text.substring(1);
      return capitalized.endsWith('.') ? capitalized : '$capitalized.';
    }

    return 'Authentication failed. Please try again.';
  }

  /// Checks if an email string is formatted correctly.
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validates an email field and returns an error string if invalid.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates a password field and returns an error string if invalid.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  /// Validates confirmation password against the original password.
  static String? validateConfirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates full name field.
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    return null;
  }
}

