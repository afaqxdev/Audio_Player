// main.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/provider.dart';
// Import your provider file - adjust path as needed

late final MyAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio service

  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
    ),
  );

  // _audioHandler = await AudioService.init(
  //   builder: () => MyAudioHandler(),
  //   config: const AudioServiceConfig(
  //     androidNotificationChannelId: 'com.example.audio',
  //     androidNotificationChannelName: 'Audio Playback',
  //     androidNotificationOngoing: true,
  //     androidResumeOnClick: true,
  //     androidShowNotificationBadge: true,
  //   ),
  // );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AudioPlayerProvider(audioHandler),
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
      title: 'Flutter Audio Book',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Player')),
      body: Center(
        child: IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => AudioPlayerScreen(
                      audioUrl:
                          'https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3',
                      name: 'Test Audio',
                    ),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow, size: 48),
        ),
      ),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  final String audioUrl;
  final String name;

  const AudioPlayerScreen({
    super.key,
    required this.audioUrl,
    required this.name,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late Future<void> _initFuture;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AudioPlayerProvider>(context, listen: false);

    _initFuture = provider.init(widget.audioUrl, widget.name).catchError((
      error,
    ) {
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        // If it's still initializing, show loading indicator

        // Handle connection error
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load audio: $_errorMessage'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: AudioPlayerUI(name: widget.name),
        );
      },
    );
  }
}

class AudioPlayerUI extends StatelessWidget {
  final String name;

  const AudioPlayerUI({super.key, required this.name});

  String formatTime(Duration duration) {
    return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, provider, child) {
        // Show error if there is one
        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${provider.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        // Show loading indicator if still loading

        return Column(
          children: [
            const SizedBox(height: 60),
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () {
                  // Stop audio when navigating back
                  provider.disposePlayer();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_ios),
              ),
            ),
            const SizedBox(height: 80),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Icon(
                  Icons.audiotrack,
                  size: 80,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Slider(
              inactiveColor: Colors.teal.withOpacity(0.3),
              activeColor: Colors.teal,
              value: provider.position.inSeconds.toDouble().clamp(
                0.0,
                provider.duration.inSeconds.toDouble() > 0
                    ? provider.duration.inSeconds.toDouble()
                    : 1.0,
              ),
              min: 0,
              max:
                  provider.duration.inSeconds.toDouble() > 0
                      ? provider.duration.inSeconds.toDouble()
                      : 1.0,
              onChanged: (value) {
                provider.seekTo(Duration(seconds: value.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTime(provider.position)),
                  Text(formatTime(provider.duration)),
                  Text("-${formatTime(provider.duration - provider.position)}"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: provider.rewind,
                  icon: const Icon(
                    Icons.replay_10,
                    size: 40,
                    color: Colors.teal,
                  ),
                ),

                IconButton(
                  onPressed: provider.togglePlayPause,
                  icon: Icon(
                    provider.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 80,
                    color: Colors.teal,
                  ),
                ),
                IconButton(
                  onPressed: provider.forward,
                  icon: const Icon(
                    Icons.forward_10,
                    size: 40,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => provider.setLoop(!provider.isLoop),
                  icon: Icon(
                    Icons.repeat,
                    size: 40,
                    color: provider.isLoop ? Colors.teal : Colors.black54,
                  ),
                ),
                IconButton(
                  onPressed: provider.toggleShuffle,
                  icon: Icon(
                    Icons.shuffle,
                    size: 40,
                    color: provider.isShuffle ? Colors.teal : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
