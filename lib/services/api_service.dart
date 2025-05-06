import 'package:http/http.dart' as http;
import 'package:test_zimpligital/model/song.dart';
import 'dart:convert';


class ApiService {
  static Future<List<Song>> fetchSongsByGenre(String genre) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.deezer.com/search?q=$genre'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<Song> songs = [];

        for (var item in jsonData['data'].take(10)) {
          final int durationInSeconds = item['duration'];
          final minutes = (durationInSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (durationInSeconds % 60).toString().padLeft(2, '0');
          final String formattedDuration = '$minutes:$seconds';

          songs.add(
            Song(
              title: item['title'],
              artist: item['artist']['name'],
              imageUrl: item['album']['cover_medium'],
              previewUrl: item['preview'],
              duration: formattedDuration,
            ),
          );
        }
        return songs;
      }
    } catch (e) {
      print('Error fetching songs for $genre: $e');
    }
    return [];
  }
}