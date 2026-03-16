import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'providers/app_provider.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const KitchenBDYApp());
}

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class KitchenBDYApp extends StatelessWidget {
  const KitchenBDYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        navigatorObservers: [routeObserver],
        title: 'Kitchen BDY',
        debugShowCheckedModeBanner: false,

        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainScreen(),
        },
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.bgPrimary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.goldPrimary,
            secondary: AppColors.goldLight,
            surface: AppColors.bgCard,
            error: AppColors.error,
          ),
          dividerColor: AppColors.borderSubtle,
          splashColor: AppColors.goldPrimary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
        ),

        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _checkLogin() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLogin(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.goldPrimary),
            ),
          );
        }

        // If logged in
        if (snapshot.data == true) {
          return const MainScreen();
        }

        // If not logged in
        return const LoginScreen();
      },
    );
  }
}
