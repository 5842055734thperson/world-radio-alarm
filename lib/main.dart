import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app_state.dart';
import 'pages/home_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.worldradio.world_radio.playback',
    androidNotificationChannelName: 'Radio playback',
    androidNotificationOngoing: true,
  );
  await initAppState();
  runApp(const WorldRadioApp());
}

class WorldRadioApp extends StatelessWidget {
  const WorldRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'World Radio',
        debugShowCheckedModeBanner: false,
        theme: brutalTheme(Brightness.light),
        darkTheme: brutalTheme(Brightness.dark),
        themeMode: settings.themeMode,
        home: const HomePage(),
      ),
    );
  }
}
