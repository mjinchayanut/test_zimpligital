import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:test_zimpligital/model/playlist.dart';
import 'package:test_zimpligital/model/song.dart';

class NowPlayingPage extends StatefulWidget {
  final Playlist playlist;
  final AudioPlayer player;
  final Song? initialSong;
  final Function(Song) onSongChanged;

  const NowPlayingPage({
    super.key,
    required this.playlist,
    required this.player,
    this.initialSong,
    required this.onSongChanged,
  });

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Song _currentSong;
  double _currentSliderValue = 0.0;
  bool _isPlaying = false;
  Duration? _currentDuration;
  bool _isLoadingSong = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentSong = widget.initialSong ?? widget.playlist.songs.first;
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    widget.player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });

    widget.player.positionStream.listen((position) {
      if (!mounted || _currentDuration == null) return;
      final totalMs = _currentDuration!.inMilliseconds;
      if (totalMs > 0) {
        setState(() {
          _currentSliderValue = position.inMilliseconds / totalMs;
          _currentSliderValue = _currentSliderValue.clamp(0.0, 1.0);
        });
      }
    });

    widget.player.durationStream.listen((duration) {
      if (mounted) setState(() => _currentDuration = duration);
    });

    widget.player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        final currentIndex = widget.playlist.songs
            .indexWhere((s) => s.previewUrl == _currentSong.previewUrl);

        if (currentIndex != -1 && currentIndex < widget.playlist.songs.length - 1) {
          _playSong(widget.playlist.songs[currentIndex + 1]);
        } else {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentSliderValue = 0.0;
            });
          }
          await widget.player.stop();
        }
      }
    });
  }

  Future<void> _playSong(Song song) async {
    if (song.previewUrl.isEmpty) return;

    try {
      if (mounted) {
        setState(() {
          _isLoadingSong = true;
          _currentSliderValue = 0.0;
          _currentSong = song;
          _isPlaying = true;
          _currentDuration = null;
        });
      }

      widget.onSongChanged(song);
      await widget.player.stop();
      await widget.player.setUrl(song.previewUrl);
      await widget.player.durationStream.firstWhere((d) => d != null);

      if (mounted) {
        setState(() {
          _currentDuration = widget.player.duration;
          _isLoadingSong = false;
        });
      }

      await widget.player.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentSliderValue = 0.0;
          _isLoadingSong = false;
        });
      }
    }
  }
@override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _currentSong.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: Icon(Icons.music_note, color: Colors.grey[400]),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentSong.title,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentSong.artist,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Theme.of(context).primaryColor,
                    size: 30,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      widget.player.pause();
                    } else {
                      widget.player.play();
                    }
                  },
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [Tab(text: 'UP NEXT'), Tab(text: 'LYRICS')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSongsList(), _buildLyricsTab()],
            ),
          ),
          _buildPlayerControls(),
        ],
      ),
    );
  }
Widget _buildSongsList() {
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final Song song = widget.playlist.songs.removeAt(oldIndex);
          widget.playlist.songs.insert(newIndex, song);
        });
      },
      padding: const EdgeInsets.only(top: 16),
      children: List.generate(widget.playlist.songs.length, (index) {
        final song = widget.playlist.songs[index];
        final isCurrentSong = song.previewUrl == _currentSong.previewUrl;

        return ListTile(
          key: Key('${song.previewUrl}_$index'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  song.imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[800],
                      child: Icon(Icons.music_note, color: Colors.grey[400]),
                    );
                  },
                ),
              ),
              if (isCurrentSong && _isPlaying)
                Icon(
                  Icons.equalizer,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
            ],
          ),
          title: Text(
            song.title,
            style: TextStyle(
              color:
                  isCurrentSong
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            '${song.artist} • ${song.duration}',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          onTap: () => _playSong(song),
        );
      }),
    );
  }

  Widget _buildLyricsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Lyrics for "${_currentSong.title}"',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Lyrics would be displayed here.\nYou can integrate with a lyrics API.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls() {
    final currentPosition =
        _currentDuration != null
            ? Duration(
              milliseconds:
                  (_currentSliderValue * _currentDuration!.inMilliseconds)
                      .round(),
            )
            : Duration.zero;

    final positionText = _formatDuration(currentPosition);
    final durationText =
        _currentDuration != null ? _formatDuration(_currentDuration!) : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                positionText,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: Theme.of(context).disabledColor,
                    thumbColor: Theme.of(context).primaryColor,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value:
                        _currentDuration != null &&
                                _currentDuration!.inMilliseconds > 0
                            ? _currentSliderValue.clamp(0.0, 1.0)
                            : 0.0,
                    onChanged:
                        _isLoadingSong
                            ? null
                            : (value) {
                              if (_currentDuration == null) return;

                              setState(() {
                                _currentSliderValue = value;
                              });

                              final position = Duration(
                                milliseconds:
                                    (value * _currentDuration!.inMilliseconds)
                                        .round(),
                              );
                              widget.player.seek(position);
                            },
                  ),
                ),
              ),
              Text(
                durationText,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(
                  Icons.skip_previous,
                  color: Theme.of(context).primaryColor,
                  size: 30,
                ),
                onPressed: _playPreviousSong,
              ),
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Theme.of(context).primaryColor,
                  size: 54,
                ),
                onPressed: () {
                  if (_isPlaying) {
                    widget.player.pause();
                  } else {
                    widget.player.play();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.skip_next,
                  color: Theme.of(context).primaryColor,
                  size: 30,
                ),
                onPressed: _playNextSong,
              ),
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _playNextSong() async {
    final currentIndex = widget.playlist.songs.indexWhere(
      (s) => s.previewUrl == _currentSong.previewUrl,
    );

    if (currentIndex != -1 && currentIndex < widget.playlist.songs.length - 1) {
      await _playSong(widget.playlist.songs[currentIndex + 1]);
    } else {
      // End of playlist
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentSliderValue = 0.0;
        });
      }
      await widget.player.stop();
    }
  }

  void _playPreviousSong() async {
    final currentIndex = widget.playlist.songs.indexWhere(
      (s) => s.previewUrl == _currentSong.previewUrl,
    );

    if (currentIndex > 0) {
      await _playSong(widget.playlist.songs[currentIndex - 1]);
    } else {
      // Restart current song
      if (mounted) {
        setState(() {
          _currentSliderValue = 0.0;
        });
      }
      await widget.player.seek(Duration.zero);
      await widget.player.play();
    }
  }
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    print("twoDigits => ${twoDigits.toString()}");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  // ... ส่วนที่เหลือของเมธอดและ build widget เหมือนเดิม ...
}