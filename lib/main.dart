import 'package:flutter/material.dart';
import 'src/rust/frb_generated.dart';
import 'services/storage_service.dart';
import 'services/ssh_service.dart';
import 'services/tunnel_service.dart';
import 'theme/app_theme.dart';
import 'views/hosts_view.dart';
import 'views/terminal_view.dart';
import 'views/keys_view.dart';
import 'views/tunnels_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RustLib
  await RustLib.init();

  // Initialize Local Storage
  await StorageService().init();

  runApp(const TerMostApp());
}

class TerMostApp extends StatelessWidget {
  const TerMostApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        ThemeMode themeMode;
        switch (storage.themeMode) {
          case 'dark':
            themeMode = ThemeMode.dark;
            break;
          case 'light':
            themeMode = ThemeMode.light;
            break;
          default:
            themeMode = ThemeMode.system;
            break;
        }

        return MaterialApp(
          title: 'TerMost SSH',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          home: const MainHomeScreen(),
        );
      },
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  void _onNavigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ssh = SshService();
    final tunnelService = TunnelService();
    final storage = StorageService();

    return ListenableBuilder(
      listenable: Listenable.merge([ssh, tunnelService, storage]),
      builder: (context, _) {
        final activeSessionsCount = ssh.sessions
            .where((s) => s.status == SshSessionStatus.connected)
            .length;
        final activeTunnelsCount = storage.rules
            .where((r) => tunnelService.isTunnelRunning(r.id))
            .length;

        final screens = [
          HostsView(onNavigateToTab: _onNavigateToTab),
          TerminalScreenView(onNavigateToTab: _onNavigateToTab),
          const KeysView(),
          const TunnelsView(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) {
              setState(() => _currentIndex = idx);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dns_outlined),
                selectedIcon: Icon(Icons.dns),
                label: '主机',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeSessionsCount > 0,
                  label: Text('$activeSessionsCount'),
                  child: const Icon(Icons.terminal_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeSessionsCount > 0,
                  label: Text('$activeSessionsCount'),
                  child: const Icon(Icons.terminal),
                ),
                label: '终端',
              ),
              const NavigationDestination(
                icon: Icon(Icons.vpn_key_outlined),
                selectedIcon: Icon(Icons.vpn_key),
                label: '密钥',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeTunnelsCount > 0,
                  label: Text('$activeTunnelsCount'),
                  child: const Icon(Icons.swap_calls_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeTunnelsCount > 0,
                  label: Text('$activeTunnelsCount'),
                  child: const Icon(Icons.swap_calls),
                ),
                label: '端口转发',
              ),
            ],
          ),
        );
      },
    );
  }
}
