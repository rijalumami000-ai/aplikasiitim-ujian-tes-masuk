import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'theme/premium_theme.dart';
import 'screens/login_screen.dart';
import 'screens/examiner_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/recap_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(apiService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (context) => DataProvider(apiService),
          update: (context, auth, previous) {
            final provider = previous ?? DataProvider(apiService);
            if (!auth.isAuthenticated) {
              provider.clear();
            }
            return provider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portal Tes Masuk Pondok Al-Hamid',
      debugShowCheckedModeBanner: false,
      theme: PremiumTheme.darkTheme,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/examiner': (context) => const ExaminerDashboard(),
        '/admin': (context) => const AdminDashboard(),
        '/recap': (context) => const RecapScreen(),
      },
    );
  }
}

// Wrapper untuk mendeteksi status login saat aplikasi baru dibuka
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Jalankan cek sesi login otomatis
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Menampilkan loading splash yang indah saat cek sesi
    if (authProvider.isLoading && !authProvider.isAuthenticated) {
      return Scaffold(
        body: PremiumBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PremiumColors.primary.withOpacity(0.15),
                    border: Border.all(color: PremiumColors.primary.withOpacity(0.3), width: 1.5),
                  ),
                  child: const CircularProgressIndicator(
                    color: PremiumColors.primaryLight,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Portal Tes Masuk Al-Hamid',
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: PremiumColors.textMain,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Memuat data sesi pengujian...',
                  style: TextStyle(fontSize: 14, color: PremiumColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Arahkan ke halaman dashboard yang sesuai atau ke halaman login
    if (authProvider.isAuthenticated) {
      if (authProvider.isSuperUser) {
        return const AdminDashboard();
      } else {
        return const ExaminerDashboard();
      }
    } else {
      return const LoginScreen();
    }
  }
}
