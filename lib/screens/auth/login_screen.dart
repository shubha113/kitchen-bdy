import 'package:flutter/material.dart';
import 'package:kitchen_bdy/screens/auth/register_screen.dart';
import 'package:kitchen_bdy/screens/main_screen.dart';
import 'package:kitchen_bdy/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Theme ─────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1A1A1A);
  static const _gold = Color(0xFFD4A843);
  static const _goldDim = Color(0xFFB8902E);
  static const _white = Colors.white;
  static const _grey = Color(0xFF888888);
  static const _border = Color(0xFF2A2A2A);

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.login(
        _emailCtrl.text,
        _passwordCtrl.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        setState(
          () => _error = result['message']?.toString() ?? 'Login failed',
        );
      }
    } catch (e) {
      print("LOGIN ERROR: $e");
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildTitle(),
                  const SizedBox(height: 32),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    _buildError(),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _buildLoginButton(),
                  const SizedBox(height: 28),
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────
  Widget _buildLogo() => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: _surface,
      shape: BoxShape.circle,
      border: Border.all(color: _gold.withOpacity(0.4), width: 2),
      boxShadow: [
        BoxShadow(
          color: _gold.withOpacity(0.15),
          blurRadius: 24,
          spreadRadius: 4,
        ),
      ],
    ),
    child: const Icon(Icons.kitchen_rounded, color: _gold, size: 36),
  );

  // ── Title ─────────────────────────────────────────────────────────────────
  Widget _buildTitle() => Column(
    children: [
      const Text(
        'KitchenBDY',
        style: TextStyle(
          color: _white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Smart kitchen management',
        style: TextStyle(color: _grey, fontSize: 14),
      ),
    ],
  );

  // ── Email field ───────────────────────────────────────────────────────────
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

  // ── Password field ────────────────────────────────────────────────────────
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
      return null;
    },
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => _login(),
  );

  // ── Error box ─────────────────────────────────────────────────────────────
  Widget _buildError() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
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

  // ── Login button ──────────────────────────────────────────────────────────
  Widget _buildLoginButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: _loading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: _goldDim.withOpacity(0.4),
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
              'Sign In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
    ),
  );

  // ── Register link ─────────────────────────────────────────────────────────
  Widget _buildRegisterLink() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        "Don't have an account? ",
        style: TextStyle(color: _grey, fontSize: 14),
      ),
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        ),
        child: const Text(
          'Register',
          style: TextStyle(
            color: _gold,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  // ── Input decoration helper ───────────────────────────────────────────────
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
