import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_repository.dart';
import 'data/app_store.dart';
import 'pages/home_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await AppRepository.open();
  runApp(MuscleApp(store: AppStore(repository)));
}

class MuscleApp extends StatelessWidget {
  const MuscleApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        title: '肌肉',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        home: const HomePage(),
      ),
    );
  }
}
