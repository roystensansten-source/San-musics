import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up background audio notifications
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music.channel.audio',
    androidNotificationChannelName: 'Music Playback',
    androidNotificationOngoing: true,
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MusicPlayerScreen(),
  ));
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  List<Video> _searchResults = [];
  bool _isLoading = false;
  String? _currentTitle;
  String? _currentArtist;

  @override
  void dispose() {
    _yt.close();
    _player.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 1. Search Logic: Searches YouTube for tracks
  Future<void> _searchSongs(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final results = await _yt.search.search(query);
      setState(() {
        _searchResults = results.toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. Stream Extractor Logic: Extracts the raw audio URL with no video and plays it
  Future<void> _playVideo(Video video) async {
    setState(() {
      _isLoading = true;
      _currentTitle = video.title;
      _currentArtist = video.author;
    });

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final audioStream = manifest.audioOnly.withHighestBitrate();

      final audioSource = AudioSource.uri(
        audioStream.url,
        tag: MediaItem(
          id: video.id.value,
          album: "YouTube Music",
          title: video.title,
          artist: video.author,
          artUri: Uri.parse(video.thumbnails.standardResUrl),
        ),
      );

      await _player.setAudioSource(audioSource);
      await _player.play();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error playing audio: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. UI Code: The visual screen with search bar, song list, and play/pause controls
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Music Player', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs or artists...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF282828),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _searchSongs(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _searchSongs,
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(color: Colors.greenAccent),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  leading: Image.network(
                    item.thumbnails.lowResUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    item.author,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () => _playVideo(item),
                );
              },
            ),
          ),
          if (_currentTitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1DB954),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentArtist ?? '',
                          maxLines: 1,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final isPlaying = state?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 40,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
