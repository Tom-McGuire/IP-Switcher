import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:provider/provider.dart';
import 'data/repositories/nic_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/gateway_ping_service.dart';
import 'data/services/nic_backend_service.dart';
import 'theme/app_theme.dart';
import 'ui/view_models/ip_setter_view_model.dart';
import 'ui/views/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final initialMode = await SharedDeviceDatabase.instance.getThemeMode();
    AppTheme.isDark = (initialMode == 'dark');
  } catch (_) {
    AppTheme.isDark = true;
  }

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

class IpSetterApp extends StatefulWidget {
  final SharedDeviceDatabase? sharedDatabase;

  const IpSetterApp({super.key, this.sharedDatabase});

  @override
  State<IpSetterApp> createState() => _IpSetterAppState();
}

class _IpSetterAppState extends State<IpSetterApp> {
  StreamSubscription<void>? _dbSub;
  String _themeMode = AppTheme.isDark ? 'dark' : 'light';

  SharedDeviceDatabase get _db =>
      widget.sharedDatabase ?? SharedDeviceDatabase.instance;

  @override
  void initState() {
    super.initState();
    _syncTheme();
    _dbSub = _db.onDatabaseChanged.listen((_) {
      _syncTheme();
    });
  }

  Future<void> _syncTheme() async {
    try {
      final mode = await _db.getThemeMode();
      if (!mounted) return;
      if (mode != _themeMode || (mode == 'dark') != AppTheme.isDark) {
        setState(() {
          _themeMode = mode;
          AppTheme.isDark = (mode == 'dark');
        });
      }
    } catch (_) {
      // Ignore transient shared DB errors and retain current theme.
    }
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IP Profile Switcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: AppTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      home: KeyedSubtree(
        key: ValueKey(_themeMode),
        child: const MainScreen(),
      ),
    );
  }
}
