// audio_provider.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerProvider extends ChangeNotifier {
  final MyAudioHandler _audioHandler;

  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  bool isLoop = false;
  bool isShuffle = false;
  String? currentUrl;
  String? errorMessage;

  AudioPlayerProvider(this._audioHandler) {
    _listenToStreams();
  }

  Future<void> init(String url, String title) async {
    print("init called with url: $url and title: $title");
    try {
      currentUrl = url;
      errorMessage = null;
      notifyListeners();

      final mediaItem = MediaItem(
        id: url,
        title: title,
        album: 'Flutter Audio Book',
        artist: 'Unknown',
        artUri: Uri.parse('https://via.placeholder.com/150'),
        displayTitle: title,
        displaySubtitle: 'Audio Book',
        displayDescription: 'Playing from Flutter Audio Book app',
      );

      await _audioHandler.playMediaItem(mediaItem);
      await _audioHandler.play();
      print("Audio initialized and playing");
    } catch (e) {
      errorMessage = "Error initializing audio: $e";
      notifyListeners();
      print("Error initializing audio: $e");
    }
  }

  void _listenToStreams() {
    print("Listening to streams...");
    _audioHandler.playbackState.listen((state) {
      print(
        'Playback state updated: isPlaying: ${state.playing}, position: ${state.updatePosition}',
      );
      isPlaying = state.playing;
      position = state.updatePosition;
      notifyListeners();

      print(
        "Playback state updated: isPlaying: $isPlaying, position: $position",
      );

      if (state.processingState == AudioProcessingState.error) {
        errorMessage = "Audio processing error";
      }

      notifyListeners();
    });

    _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        duration = item.duration ?? Duration.zero;
        print("Media item updated: duration: $duration");
        notifyListeners();
      }
    });

    _audioHandler.player.playbackEventStream.listen(
      (event) {
        if (event.processingState == ProcessingState.ready) {
          notifyListeners();
          print("Playback event processed: ready");
        }
      },
      onError: (Object e, StackTrace stackTrace) {
        errorMessage = "Playback error: $e";
        notifyListeners();
        print("Error in playback event stream: $e");
      },
    );
  }

  void togglePlayPause() {
    print('Toggle Play/Pause called');
    if (isPlaying) {
      print('Pausing');
      _audioHandler.pause();
    } else {
      print('Playing');
      _audioHandler.play();
    }
  }

  void seekTo(Duration pos) {
    print("Seeking to position: $pos");
    _audioHandler.seek(pos);
  }

  void rewind() {
    final newPosition =
        position - const Duration(seconds: 10) < Duration.zero
            ? Duration.zero
            : position - const Duration(seconds: 10);
    print("Rewinding to position: $newPosition");
    _audioHandler.seek(newPosition);
  }

  void forward() {
    final newPosition =
        position + const Duration(seconds: 10) > duration
            ? duration
            : position + const Duration(seconds: 10);
    print("Fast forwarding to position: $newPosition");
    _audioHandler.seek(newPosition);
  }

  void setLoop(bool loop) {
    print("Setting loop mode to: $loop");
    isLoop = loop;
    _audioHandler.player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  void toggleShuffle() {
    print("Toggling shuffle mode");
    isShuffle = !isShuffle;
    _audioHandler.player.setShuffleModeEnabled(isShuffle);
    notifyListeners();
  }

  void disposePlayer() {
    print("Disposing player");
    _audioHandler.stop();
    notifyListeners();
  }
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  MyAudioHandler() {
    print("MyAudioHandler initialized");
    _notifyAudioHandlerAboutPlaybackEvents();
    playbackState.add(
      PlaybackState(
        controls: [
          if (_player.playing) MediaControl.pause else MediaControl.play,
        ],
        systemActions: const {MediaAction.rewind, MediaAction.fastForward},
        androidCompactActionIndices: const [1, 2],
        processingState: AudioProcessingState.idle,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 1,
      ),
    );
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    print("Notifying audio handler about playback events...");
    _player.playbackEventStream.listen(
      (event) {
        final processingState =
            {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState] ??
            AudioProcessingState.idle;

        print("Playback event: $event");
        playbackState.add(
          PlaybackState(
            controls: [
              MediaControl.rewind,
              MediaControl.pause,
              MediaControl.play,
              MediaControl.fastForward,
            ],

            systemActions: const {
              MediaAction.seek,
              MediaAction.playPause,
              MediaAction.pause,
              MediaAction.play,
            },
            androidCompactActionIndices: const [1, 2],
            processingState: processingState,
            playing: _player.playing,
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            speed: _player.speed,
            queueIndex: 1,
          ),
        );
      },
      onError: (Object e, StackTrace st) {
        print('Error in playback event stream: $e');
      },
    );

    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        final updatedItem = mediaItem.value!.copyWith(duration: duration);
        mediaItem.add(updatedItem);
        print("Duration updated: $duration");
      }
    });
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    print("playMediaItem called with item: $item");
    try {
      await _player.stop();
      final source = AudioSource.uri(Uri.parse(item.id), tag: item);
      await _player.setAudioSource(source, preload: true);
      mediaItem.add(item);

      _player.durationStream.first.then((duration) {
        if (duration != null) {
          final updatedItem = item.copyWith(duration: duration);
          mediaItem.add(updatedItem);
        }
      });
      print("Media item played");
    } catch (e) {
      print('Error in playMediaItem: $e');
      throw Exception('Failed to load audio source: $e');
    }
  }

  @override
  Future<void> play() async {
    print("play called");
    await _player.play();
  }

  @override
  Future<void> pause() async {
    print("pause called");
    try {
      if (_player.playing) {
        await _player.pause();
        playbackState.add(playbackState.value.copyWith(playing: false));
      } else {
        await _player.play();
        playbackState.add(
          playbackState.value.copyWith(playing: true),
        ); // ✅ correct state
      }
    } catch (e, stackTrace) {
      print('[AudioPlayer] Error during pause: $e');
      print('[AudioPlayer] StackTrace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    print("stop called");
    // if (_player.playing) {
    //   await _player.pause();
    //   playbackState.add(playbackState.value.copyWith(playing: false));
    // } else {
    //   await _player.play();
    //   playbackState.add(
    //     playbackState.value.copyWith(playing: true),
    //   ); // ✅ correct state
    // }
    // playbackState.add(
    //   playbackState.value.copyWith(
    //     processingState: AudioProcessingState.idle,
    //     playing: false,
    //   ),
    // );
  }

  @override
  Future<void> seek(Duration position) async {
    print("seek called to position: $position");
    await _player.seek(position);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    print("rewind called, seeking to position: $newPosition");
    await _player.seek(newPosition);
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + const Duration(seconds: 10);
    print("fastForward called, seeking to position: $newPosition");
    await _player.seek(newPosition);
  }
}
