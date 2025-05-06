import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:test_zimpligital/model/playlist.dart';
import 'package:test_zimpligital/model/song.dart';
import 'package:test_zimpligital/pages/now_playing_page.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PanelController _panelController = PanelController();
  final player = AudioPlayer();
  List<Playlist> playlists = [];
  Playlist? currentPlaylist;
  Song? currentSong;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    setState(() => isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      final List<Playlist> demoPlaylists = [
        Playlist(
          name: 'Tech House Vibes',
          description: 'A&K',
          imageUrl: 'https://picsum.photos/seed/tech/200/200',
          songs: await ApiService.fetchSongsByGenre('techno'),
        ),
        // เพิ่ม playlist ใหม่ที่นี่
        Playlist(
          name: 'Chill Mix',
          description: 'Relaxing tracks for your mood',
          imageUrl: 'https://picsum.photos/seed/chill/200/200',
          songs: await ApiService.fetchSongsByGenre('chill'),
        ),
        Playlist(
          name: 'Rock Classics',
          description: 'Timeless rock anthems',
          imageUrl: 'https://picsum.photos/seed/rock/200/200',
          songs: await ApiService.fetchSongsByGenre('rock'),
        ),
        Playlist(
          name: 'Pop Hits 2024',
          description: 'Today\'s biggest pop songs',
          imageUrl: 'https://picsum.photos/seed/pop/200/200',
          songs: await ApiService.fetchSongsByGenre('pop'),
        ),
      ];

      setState(() {
        playlists = demoPlaylists;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _openPlaylist(Playlist playlist) {
    setState(() {
      currentPlaylist = playlist;
      if (playlist.songs.isNotEmpty) {
        currentSong = playlist.songs[0];
        player.setUrl(currentSong!.previewUrl).then((_) => player.play());
      }
    });

    if (_panelController.isPanelClosed) {
      _panelController.open();
    }
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          playlist.imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 56,
              height: 56,
              color: Colors.grey[300],
              child: Icon(Icons.music_note, color: Colors.grey[600]),
            );
          },
        ),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(playlist.description),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow_rounded),
        iconSize: 30,
        onPressed: () => _openPlaylist(playlist),
      ),
      onTap: () => _openPlaylist(playlist),
    );
  }

  Widget _buildMiniPlayer() {
    if (currentSong == null) return const SizedBox.shrink();

    return Column(
      children: [
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            return StreamBuilder<Duration?>(
              stream: player.durationStream,
              builder: (context, durationSnapshot) {
                final total = durationSnapshot.data ?? Duration.zero;
                final progress =
                    total.inMilliseconds > 0
                        ? position.inMilliseconds / total.inMilliseconds
                        : 0.0;

                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * progress,
                    height: 2,
                    child: Container(color: Colors.yellow),
                  ),
                );
              },
            );
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
          decoration: BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  currentSong!.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: Icon(Icons.music_note, color: Colors.grey[600]),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentPlaylist?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentPlaylist?.description ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon:
                    player.playing ? Icon(Icons.pause) : Icon(Icons.play_arrow),
                onPressed: () {
                  player.playing ? player.pause() : player.play();
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Playlist'), elevation: 0),
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: currentSong != null ? 120 : 0,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        panel:
            currentPlaylist != null
                ? NowPlayingPage(
                  playlist: currentPlaylist!,
                  player: player,
                  initialSong: currentSong,
                  onSongChanged: (song) {
                    setState(() => currentSong = song);
                  },
                )
                : const SizedBox.shrink(),
        collapsed: GestureDetector(
          onTap: () => _panelController.open(),
          child: _buildMiniPlayer(),
        ),
        body:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: playlists.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder:
                      (context, index) => _buildPlaylistTile(playlists[index]),
                ),
      ),
    );
  }
}
