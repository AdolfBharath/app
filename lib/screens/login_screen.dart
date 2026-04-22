import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'admin_home_screen.dart';
import '../features/mentor/presentation/screens/mentor_home_screen.dart';
import '../features/student/presentation/screens/student_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _rememberEmailKey = 'remember_email';
  static const String _rememberEnabledKey = 'remember_email_enabled';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberEnabled = prefs.getBool(_rememberEnabledKey) ?? false;
    final rememberedEmail = prefs.getString(_rememberEmailKey) ?? '';

    if (!mounted) return;
    setState(() {
      _rememberEmail = rememberEnabled;
      _emailController.text = rememberEnabled ? rememberedEmail : '';
      _passwordController.clear();
    });
  }

  Future<void> _persistRememberPreference(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberEnabledKey, _rememberEmail);
    if (_rememberEmail) {
      await prefs.setString(_rememberEmailKey, email);
    } else {
      await prefs.remove(_rememberEmailKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await auth.login(email, password);

    setState(() {
      _isLoading = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.lastLoginError ?? 'Invalid email or password',
          ),
        ),
      );
      return;
    }

    await _persistRememberPreference(email);

    if (!mounted) return;

    if (auth.currentRole == UserRole.admin) {
      // For admins, go to the admin panel and clear the stack so
      // back does not return to the public marketplace while logged in.
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AdminHomeScreen.routeName, (route) => false);
    } else if (auth.currentRole == UserRole.mentor) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(MentorHomeScreen.routeName, (r) => false);
    } else {
      // For students, go directly into the dedicated student shell
      // with bottom navigation, coins, streaks, etc.
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(StudentShellScreen.routeName, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 16 + viewInsets.bottom,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top logo row (logo only, larger)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/favicon.png',
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.06),
                                child: Icon(
                                  Icons.help_outline,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: size.height * 0.015),
                          Center(
                            child: Image.asset(
                              'assets/girl.png',
                              height: size.height * 0.22,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: size.height * 0.01),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Text(
                                'Hello again',
                                style: GoogleFonts.greatVibes(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF1F1F39),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Center(
                              child: Text(
                                'Ready to continue your learning?',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF858597),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'EMAIL ADDRESS',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF858597),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'alex@example.com',
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF7F7FB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PASSWORD',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF858597),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F7FB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _rememberEmail,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberEmail = value ?? false;
                                          });
                                        },
                                        activeColor: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Remember me',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF1F1F39),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {},
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Log in',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.arrow_right_alt_rounded,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
