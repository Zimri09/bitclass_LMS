import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/glow_card.dart';
import '../bloc/auth_bloc.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthPasswordUpdateRequested(_passwordController.text),
    );
  }

  void _cancel() {
    context.read<AuthBloc>().add(AuthLogoutRequested());
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(onPressed: _cancel, icon: const Icon(Icons.close)),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthPasswordResetComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Password updated successfully. Sign in with your new password.',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            context.go(AppRoutes.login);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                action: isNetworkFailure(state.message)
                    ? SnackBarAction(label: 'Retry', onPressed: _submit)
                    : null,
              ),
            );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlowCard(
                glowColor: AppColors.secondary,
                glowIntensity: 0.18,
                isHoverable: false,
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.password_outlined,
                        size: 52,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create a new password',
                        style: AppTextStyles.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use at least 8 characters. You will sign in again after the password is changed.',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      _passwordField(),
                      const SizedBox(height: 16),
                      _confirmationField(),
                      const SizedBox(height: 28),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isLoading =
                              state is AuthLoading &&
                              state.operation == AuthOperation.updatingPassword;
                          return ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Update Password'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'New Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a new password';
        }
        if (value.length < 8) {
          return 'Password must contain at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _confirmationField() {
    return TextFormField(
      controller: _confirmController,
      obscureText: _obscureConfirmation,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Confirm New Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscureConfirmation = !_obscureConfirmation);
          },
          icon: Icon(
            _obscureConfirmation
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your new password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }
}
