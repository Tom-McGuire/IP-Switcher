import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/nic_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/gateway_ping_service.dart';
import 'data/services/nic_backend_service.dart';
import 'theme/app_theme.dart';
import 'ui/view_models/ip_setter_view_model.dart';
import 'ui/views/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final databaseService = DatabaseService();
  final nicBackendService = NicBackendService();
  final gatewayPingService = GatewayPingService();

  final profileRepository = ProfileRepository(databaseService);
  final nicRepository = NicRepository(nicBackendService, gatewayPingService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<IpSetterViewModel>(
          create: (_) => IpSetterViewModel(
            profileRepository: profileRepository,
            nicRepository: nicRepository,
          )..initialize(),
        ),
      ],
      child: const IpSetterApp(),
    ),
  );
}

class IpSetterApp extends StatelessWidget {
  const IpSetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IP Profile Switcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.dark,
      home: const MainScreen(),
    );
  }
}
