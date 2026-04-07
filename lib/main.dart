import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> setupNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await setupNotifications();

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
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

class KitchenBDYApp extends StatelessWidget {
  const KitchenBDYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp(
            scaffoldMessengerKey: messengerKey,
            navigatorObservers: [routeObserver],
            title: 'Kitchen BDY',
            debugShowCheckedModeBanner: false,
            themeMode: themeProv.mode,

            // Dark Theme
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
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

            // Light Theme
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.lightBgPrimary,
              colorScheme: const ColorScheme.light(
                primary: AppColors.goldPrimary,
                secondary: AppColors.goldDark,
                surface: AppColors.lightBgCard,
                error: AppColors.error,
              ),
              dividerColor: AppColors.lightBorderSubtle,
              splashColor: AppColors.goldPrimary.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
            ),

            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainScreen(),
            },
            home: const AuthGate(),
          );
        },
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.goldPrimary),
            ),
          );
        }
        return snapshot.data == true ? const MainScreen() : const LoginScreen();
      },
    );
  }
}
