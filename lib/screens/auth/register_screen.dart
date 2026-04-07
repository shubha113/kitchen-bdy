import 'package:app/services/auth_service.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Theme
  static const _bg = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1A1A1A);
  static const _gold = Color(0xFFD4A843);
  static const _goldDim = Color(0xFFB8902E);
  static const _white = Colors.white;
  static const _grey = Color(0xFF888888);
  static const _border = Color(0xFF2A2A2A);

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  bool _obscureConf = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final result = await ApiService.register(
        _emailCtrl.text,
        _passwordCtrl.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _success = 'Account created! Please sign in.';
          _loading = false;
        });

        // Wait 1.5s then go back to login
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context);
      } else {
        setState(
          () => _error = result['message']?.toString() ?? 'Registration failed',
        );
      }
    } catch (e) {
      setState(
        () => _error =
            'Could not connect to server. Check your internet connection.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: _white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 28),
                  _buildTitle(),
                  const SizedBox(height: 32),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildConfirmField(),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    _buildError(),
                    const SizedBox(height: 12),
                  ],
                  if (_success != null) ...[
                    _buildSuccess(),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _buildRegisterButton(),
                  const SizedBox(height: 28),
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      color: _surface,
      shape: BoxShape.circle,
      border: Border.all(color: _gold.withValues(alpha: 0.4), width: 2),
      boxShadow: [
        BoxShadow(
          color: _gold.withValues(alpha: 0.12),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ],
    ),
    child: const Icon(Icons.person_add_outlined, color: _gold, size: 32),
  );

  Widget _buildTitle() => Column(
    children: [
      const Text(
        'Create Account',
        style: TextStyle(
          color: _white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Join KitchenBDY to manage your devices',
        style: TextStyle(color: _grey, fontSize: 13),
      ),
    ],
  );

  Widget _buildEmailField() => TextFormField(
    controller: _emailCtrl,
    keyboardType: TextInputType.emailAddress,
    style: const TextStyle(color: _white, fontSize: 15),
    decoration: _inputDec(label: 'Email', icon: Icons.email_outlined),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return 'Email is required';
      if (!v.contains('@')) return 'Enter a valid email';
      return null;
    },
    textInputAction: TextInputAction.next,
  );

  Widget _buildPasswordField() => TextFormField(
    controller: _passwordCtrl,
    obscureText: _obscure,
    style: const TextStyle(color: _white, fontSize: 15),
    decoration: _inputDec(
      label: 'Password',
      icon: Icons.lock_outline_rounded,
      suffix: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _grey,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Password is required';
      if (v.length < 6) return 'Password must be at least 6 characters';
      return null;
    },
    textInputAction: TextInputAction.next,
  );

  Widget _buildConfirmField() => TextFormField(
    controller: _confirmCtrl,
    obscureText: _obscureConf,
    style: const TextStyle(color: _white, fontSize: 15),
    decoration: _inputDec(
      label: 'Confirm Password',
      icon: Icons.lock_outline_rounded,
      suffix: IconButton(
        icon: Icon(
          _obscureConf
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _grey,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureConf = !_obscureConf),
      ),
    ),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Please confirm your password';
      if (v != _passwordCtrl.text) return 'Passwords do not match';
      return null;
    },
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => _register(),
  );

  Widget _buildError() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildSuccess() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _success!,
            style: const TextStyle(color: Colors.green, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildRegisterButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: _loading ? null : _register,
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: _goldDim.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.black,
              ),
            )
          : const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
    ),
  );

  Widget _buildLoginLink() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        'Already have an account? ',
        style: TextStyle(color: _grey, fontSize: 14),
      ),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Text(
          'Sign In',
          style: TextStyle(
            color: _gold,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  InputDecoration _inputDec({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: _grey, fontSize: 14),
    prefixIcon: Icon(icon, color: _grey, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: _surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}
