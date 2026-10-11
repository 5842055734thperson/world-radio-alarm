import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app_state.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.worldradio.world_radio.playback',
    androidNotificationChannelName: 'Radyo çalma',
    androidNotificationOngoing: true,
  );
  await initAppState();
  runApp(const WorldRadioApp());
}

class WorldRadioApp extends StatelessWidget {
  const WorldRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: b,
          ),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'Dünya Radyo',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}
