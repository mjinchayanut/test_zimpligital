class Song {
  final String title;
  final String artist;
  final String imageUrl;
  final String previewUrl;
  final String duration;

  Song({
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.previewUrl,
    this.duration = '',
  });
}