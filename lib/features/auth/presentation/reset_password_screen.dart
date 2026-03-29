import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/auth_notifier.dart';
import '../domain/auth_state.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _codeVerified = false;
  bool _handlingSuccess = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final email = GoRouterState.of(context).uri.queryParameters['email'] ?? '';
    if (email.isNotEmpty && _emailController.text != email) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _verifyCode() {
    if (!_validateIdentityFields()) return;
    ref.read(authNotifierProvider.notifier).verifyRecoveryCode(
      _emailController.text.trim(),
      _codeController.text.trim(),
    );
  }

  bool _validateIdentityFields() {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email obligatoire.')),
      );
      return false;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format email invalide.')),
      );
      return false;
    }

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code obligatoire.')),
      );
      return false;
    }

    return true;
  }

  void _submitNewPassword() {
    if (!_codeVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérifie d’abord le code reçu par email.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    ref.read(authNotifierProvider.notifier).updatePassword(
      _passwordController.text.trim(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF2E86AB).withValues(alpha: 0.8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E86AB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.success && !_handlingSuccess) {
        _handlingSuccess = true;

        if (!_codeVerified) {
          setState(() {
            _codeVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code validé. Vous pouvez maintenant définir un nouveau mot de passe.'),
            ),
          );
          ref.read(authNotifierProvider.notifier).reset();
        } else {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Succès', style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text('Votre mot de passe a été mis à jour avec succès.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Supabase.instance.client.auth.signOut();
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E86AB)),
                  ),
                ),
              ],
            ),
          );
          ref.read(authNotifierProvider.notifier).reset();
        }

        _handlingSuccess = false;
      }

      if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Erreur inconnue'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(authNotifierProvider.notifier).reset();
      }
    });

    final currentUser = Supabase.instance.client.auth.currentUser;
    final canChangePassword = _codeVerified || currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E3A5F)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/forgot-password');
            }
          },
          tooltip: 'Retour',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E86AB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      size: 50,
                      color: Color(0xFF2E86AB),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Réinitialiser le mot de passe',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A5F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Entrez l\'email et le code reçu, puis choisissez votre nouveau mot de passe.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildTextField(
                          controller: _emailController,
                          labelText: 'Adresse email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_codeVerified,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _codeController,
                          labelText: 'Code reçu par email',
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                          enabled: !_codeVerified,
                        ),
                        const SizedBox(height: 16),
                        if (!_codeVerified)
                          authState.status == AuthStatus.loading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E86AB)))
                              : OutlinedButton(
                                  onPressed: _verifyCode,
                                  child: const Text('Vérifier le code'),
                                ),
                        if (_codeVerified) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F6EE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF1F8F55)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Code vérifié. Vous pouvez définir votre nouveau mot de passe.',
                                    style: TextStyle(
                                      color: Color(0xFF1F8F55),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildTextField(
                          controller: _passwordController,
                          labelText: 'Nouveau mot de passe',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          enabled: canChangePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (!canChangePassword) return null;
                            if (value == null || value.isEmpty) return 'Mot de passe obligatoire';
                            if (value.length < 6) return 'Minimum 6 caractères';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _confirmController,
                          labelText: 'Confirmation',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          enabled: canChangePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (value) {
                            if (!canChangePassword) return null;
                            if (value == null || value.isEmpty) return 'Confirmation obligatoire';
                            if (value != _passwordController.text) {
                              return 'Les mots de passe ne correspondent pas';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        authState.status == AuthStatus.loading && _codeVerified
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E86AB)))
                            : Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2E86AB), Color(0xFF1E5B7A)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2E86AB).withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: canChangePassword ? _submitNewPassword : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Mettre à jour',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            final email = Uri.encodeComponent(_emailController.text.trim());
                            context.go('/forgot-password${email.isNotEmpty ? '?email=$email' : ''}');
                          },
                          child: const Text('Renvoyer un code'),
                        ),
                      ],
                    ),
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
