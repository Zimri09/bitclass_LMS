import 'package:flutter/material.dart';

import '../../../core/auth/admin_session_controller.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_brand_logo.dart';

class AdminLoginScreen extends StatefulWidget {
  final AdminSessionController session;

  const AdminLoginScreen({super.key, required this.session});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.session.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showBrandPanel = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (showBrandPanel)
                const Expanded(flex: 5, child: _AdminBrandPanel()),
              Expanded(
                flex: showBrandPanel ? 4 : 1,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: AnimatedBuilder(
                        animation: widget.session,
                        builder: (context, _) => _buildForm(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final session = widget.session;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CompactBrand(),
            const SizedBox(height: 40),
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text('Sign in with an authorized administrator account.'),
            const SizedBox(height: 28),
            if (session.message != null) ...[
              _LoginMessage(message: session.message!),
              const SizedBox(height: 18),
            ],
            TextFormField(
              controller: _emailController,
              enabled: !session.isSubmitting,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Enter your email address.';
                if (!email.contains('@')) return 'Enter a valid email address.';
                return null;
              },
              onChanged: (_) => session.clearMessage(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !session.isSubmitting,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  (value?.isEmpty ?? true) ? 'Enter your password.' : null,
              onChanged: (_) => session.clearMessage(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: session.isSubmitting ? null : _submit,
              child: session.isSubmitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Sign in to Admin'),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AdminColors.textSecondary,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Access is checked against your database role.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        AdminBrandLogo(size: 42),
        SizedBox(width: 12),
        Text(
          'BitClass Admin',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _AdminBrandPanel extends StatelessWidget {
  const _AdminBrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AdminColors.navigation,
        border: Border(right: BorderSide(color: AdminColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CompactBrand(),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AdminColors.primarySoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'ADMINISTRATION',
                style: TextStyle(
                  color: AdminColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Manage your learning community with clarity.',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontSize: 42, height: 1.12),
            ),
            const SizedBox(height: 20),
            const Text(
              'Monitor users, courses, enrollment activity, and submissions '
              'from one secure workspace.',
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const Spacer(),
            const Text(
              'BitClass Learning Management System',
              style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginMessage extends StatelessWidget {
  final String message;

  const _LoginMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.danger.withValues(alpha: 0.1),
        border: Border.all(color: AdminColors.danger.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AdminColors.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
