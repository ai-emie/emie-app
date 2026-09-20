import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum AppleConfirmationNativeStatus { proof, cancelled, unavailable, stale }

class AppleConfirmationNativeResult {
  const AppleConfirmationNativeResult(this.status, {this.identityToken, this.state});
  final AppleConfirmationNativeStatus status;
  final String? identityToken;
  final String? state;
}

class AppleConfirmationNative {
  bool get isSupported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
       defaultTargetPlatform == TargetPlatform.macOS);

  Future<AppleConfirmationNativeResult> request({required String nonce,
      required String state, required bool Function() isCurrent}) async {
    if (!isCurrent()) {
      return const AppleConfirmationNativeResult(AppleConfirmationNativeStatus.stale);
    }
    if (!isSupported) {
      return const AppleConfirmationNativeResult(AppleConfirmationNativeStatus.unavailable);
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
          scopes: const [], nonce: nonce, state: state);
      if (!isCurrent()) {
        return const AppleConfirmationNativeResult(AppleConfirmationNativeStatus.stale);
      }
      // Do not copy, persist, send or log the authorizationCode or full credential.
      return AppleConfirmationNativeResult(AppleConfirmationNativeStatus.proof,
          identityToken: credential.identityToken, state: credential.state);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (!isCurrent()) {
        return const AppleConfirmationNativeResult(AppleConfirmationNativeStatus.stale);
      }
      return AppleConfirmationNativeResult(error.code == AuthorizationErrorCode.canceled
          ? AppleConfirmationNativeStatus.cancelled : AppleConfirmationNativeStatus.unavailable);
    } catch (_) {
      return AppleConfirmationNativeResult(isCurrent()
          ? AppleConfirmationNativeStatus.unavailable : AppleConfirmationNativeStatus.stale);
    }
  }
}
