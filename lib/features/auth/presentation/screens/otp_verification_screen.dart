import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../../auth_otp.dart';
import '../bloc/auth_bloc.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _cancel() {
    context.read<AuthBloc>().add(AuthOtpCancelled());
    context.go(AppRoutes.login);
  }

  void _verify(AuthOtpChallenge challenge) {
    if (_otpController.text.length != authEmailOtpLength) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authEmailOtpInputMessage)));
      return;
    }
    if (!challenge.canAttempt) return;
    context.read<AuthBloc>().add(
      AuthOtpVerificationRequested(_otpController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: _cancel,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go(AppRoutes.dashboard);
          } else if (state is AuthPasswordResetRequired) {
            context.go(AppRoutes.resetPassword);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is! AuthOtpChallenge) {
            return _buildMissingChallenge();
          }
          return _buildChallenge(state);
        },
      ),
    );
  }

  Widget _buildChallenge(AuthOtpChallenge challenge) {
    final isSignup = challenge.purpose == AuthOtpPurpose.signup;
    final expiresIn = _remaining(challenge.expiresAt);
    final resendIn = _remaining(challenge.resendAvailableAt);
    final canResend =
        resendIn == Duration.zero &&
        !challenge.isResending &&
        !challenge.isVerifying;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GlowCard(
            glowColor: AppColors.primary,
            glowIntensity: 0.18,
            isHoverable: false,
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      isSignup
                          ? Icons.mark_email_unread_outlined
                          : Icons.lock_reset_outlined,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isSignup ? 'Verify your email' : 'Verify recovery code',
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the $authEmailOtpLength-digit code sent to\n'
                  '${challenge.email}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gmail often files this under Promotions or Spam. '
                  'The code is in the email subject and body — not a Confirm link.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _otpController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  maxLength: authEmailOtpLength,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(authEmailOtpLength),
                  ],
                  onSubmitted: (_) => _verify(challenge),
                  style: AppTextStyles.h2.copyWith(
                    letterSpacing: 12,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusMessage(challenge),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      expiresIn == Duration.zero
                          ? 'Code expired'
                          : 'Expires in ${_format(expiresIn)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: expiresIn == Duration.zero
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${challenge.attemptsRemaining} attempts left',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed:
                      challenge.canAttempt &&
                          !challenge.isVerifying &&
                          !challenge.isResending
                      ? () => _verify(challenge)
                      : null,
                  child: challenge.isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify Code'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: canResend
                      ? () {
                          _otpController.clear();
                          context.read<AuthBloc>().add(
                            AuthOtpResendRequested(),
                          );
                        }
                      : null,
                  child: challenge.isResending
                      ? const Text('Sending...')
                      : Text(
                          canResend
                              ? 'Resend code'
                              : 'Resend in ${_format(resendIn)}',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage(AuthOtpChallenge challenge) {
    final error = challenge.errorMessage;
    final success = challenge.successMessage;
    if (error == null && success == null) return const SizedBox.shrink();

    final isError = error != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? AppColors.error : AppColors.success).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        error ?? success!,
        style: AppTextStyles.bodySmall.copyWith(
          color: isError ? AppColors.error : AppColors.success,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMissingChallenge() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_outlined, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Verification session expired', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Start again to request a new verification code.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cancel,
              child: const Text('Back to Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Duration _remaining(DateTime target) {
    final value = target.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
