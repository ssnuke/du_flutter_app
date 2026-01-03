import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  final List<Map<String, dynamic>> people = const [
    {
      "name": "Riya Sharma",
      "bio": "Top performer - Sales team",
      "imageUrl": "https://i.pravatar.cc/150?img=5",
      "videos": [
        {
          "title": "Closing Big Deals",
          "url":
              "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"
        },
        {
          "title": "Client Retention Tips",
          "url":
              "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"
        },
      ]
    },
    {
      "name": "Arjun Mehta",
      "bio": "Innovation in Product Design",
      "imageUrl": "https://i.pravatar.cc/150?img=12",
      "videos": [
        {
          "title": "Design Thinking 101",
          "url":
              "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"
        },
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Celebrating Our Top Performers",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap on a profile to watch their top moments & insights.",
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),

          // List of cards
          ...people.map((person) => Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(person["imageUrl"]),
                    radius: 28,
                  ),
                  title: Text(person["name"],
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(person["bio"],
                      style: const TextStyle(color: Colors.white70)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.cyanAccent),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoListPage(
                          name: person["name"],
                          videos:
                              List<Map<String, String>>.from(person["videos"]),
                        ),
                      ),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }
}

class VideoListPage extends StatelessWidget {
  final String name;
  final List<Map<String, String>> videos;

  const VideoListPage({super.key, required this.name, required this.videos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("$name's Videos"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return ListTile(
            title: Text(video["title"]!,
                style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.play_arrow, color: Colors.cyanAccent),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerPage(
                      title: video["title"]!, url: video["url"]!),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String title;
  final String url;

  const VideoPlayerPage({super.key, required this.title, required this.url});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}
