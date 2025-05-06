import 'package:test_zimpligital/model/song.dart';

class Playlist {
  final String name;
  final String description;
  final String imageUrl;
  final List<Song> songs;

  Playlist({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.songs,
  });
}