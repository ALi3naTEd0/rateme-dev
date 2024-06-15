import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'bandcamp_parser.dart';
import 'footer.dart';
import 'app_theme.dart';
import 'user_data.dart';
import 'package:url_launcher/url_launcher.dart';

class BandcampDetailsPage extends StatefulWidget {
  final dynamic album;

  BandcampDetailsPage({Key? key, required this.album}) : super(key: key);

  @override
  _BandcampDetailsPageState createState() => _BandcampDetailsPageState();
}

class _BandcampDetailsPageState extends State<BandcampDetailsPage> {
  List<Map<String, dynamic>> tracks = [];
  Map<int, double> ratings = {};
  double averageRating = 0.0;
  int albumDurationMillis = 0;
  bool isLoading = true;
  DateTime? releaseDate;

  @override
  void initState() {
    super.initState();
    _fetchAlbumDetails();
    _loadRatings();
  }

  void _fetchAlbumDetails() async {
    final url = widget.album['url'];

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = BandcampParser.extractBandcampJson(response.body);
        final tracksData = BandcampParser.extractTracks(jsonData);

        setState(() {
          tracks = tracksData;
          releaseDate = jsonData['datePublished'] != null
              ? DateTime.tryParse(jsonData['datePublished'])
              : null;
          isLoading = false;
          calculateAlbumDuration();
        });
      } else {
        throw Exception('Failed to load album page');
      }
    } catch (error) {
      print('Error fetching album details: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _loadRatings() async {
    int albumId = widget.album['collectionId'];
    List<Map<String, dynamic>> savedRatings = await UserData.getSavedAlbumRatings(albumId);
    Map<int, double> ratingsMap = {};
    savedRatings.forEach((rating) {
      int trackId = rating['trackId'];
      double ratingValue = rating['rating'];
      ratingsMap[trackId] = ratingValue;
    });

    setState(() {
      ratings = ratingsMap;
      calculateAverageRating();
    });
  }

  void calculateAverageRating() {
    var ratedTracks = ratings.values.where((rating) => rating > 0).toList();
    if (ratedTracks.isNotEmpty) {
      double total = ratedTracks.reduce((a, b) => a + b);
      setState(() {
        averageRating = total / ratedTracks.length;
        averageRating = double.parse(averageRating.toStringAsFixed(2));
      });
    } else {
      setState(() => averageRating = 0.0);
    }
  }

  void calculateAlbumDuration() {
    int totalDuration = 0;
    tracks.forEach((track) {
      totalDuration += track['duration'] as int;
    });
    setState(() {
      albumDurationMillis = totalDuration;
    });
  }

  void _updateRating(int trackId, double newRating) async {
    setState(() {
      ratings[trackId] = newRating;
      calculateAverageRating();
    });

    int albumId = widget.album['collectionId'];
    await UserData.saveRating(albumId, trackId, newRating);
    print('Updated rating for trackId $trackId: $newRating');
  }

  void _printSavedIds(int collectionId, List<int> trackIds) {
    print('Saved album information:');
    print('CollectionId: $collectionId');
    print('TrackIds: $trackIds');
  }

  void _saveAlbum() async {
    await UserData.saveAlbum(widget.album);
    List<int> trackIds = tracks.map((track) => track['track_id'] ?? 0).cast<int>().toList();
    _printSavedIds(widget.album['collectionId'], trackIds);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Album saved in history'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _launchRateYourMusic() async {
    final artistName = widget.album['artistName'];
    final albumName = widget.album['collectionName'];
    final url =
        'https://rateyourmusic.com/search?searchterm=${Uri.encodeComponent(artistName)}+${Uri.encodeComponent(albumName)}&searchtype=l';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (error) {
      print('Error launching RateYourMusic: $error');
    }
  }

  String formatDuration(int millis) {
    int seconds = (millis ~/ 1000) % 60;
    int minutes = (millis ~/ 1000) ~/ 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album['collectionName'] ?? 'Unknown Album'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        widget.album['artworkUrl100']
                                ?.replaceAll('100x100', '600x600') ??
                            '',
                        width: 300,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.album, size: 300),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildInfoRow("Artist: ", widget.album['artistName'] ?? 'Unknown Artist'),
                          _buildInfoRow("Album: ", widget.album['collectionName'] ?? 'Unknown Album'),
                          _buildInfoRow("Release Date: ", releaseDate != null
                                  ? DateFormat('dd-MM-yyyy').format(releaseDate!)
                                  : 'Unknown Date'),
                          _buildInfoRow("Duration: ", formatDuration(albumDurationMillis)),
                          _buildRatingRow(),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildButton('Save Album', _saveAlbum),
                    Divider(),
                    _buildTracksDataTable(),
                    SizedBox(height: 20),
                    _buildButton('Rate on RateYourMusic', _launchRateYourMusic),
                    SizedBox(height: 20),
                    Footer(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }

  Widget _buildRatingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Rating: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(averageRating.toStringAsFixed(2), style: TextStyle(fontSize: 20)),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkTheme.colorScheme.primary
            : AppTheme.lightTheme.colorScheme.primary,
      ),
    );
  }

  Widget _buildTracksDataTable() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Track No.', textAlign: TextAlign.center)),
        DataColumn(label: Text('Title', textAlign: TextAlign.left)),
        DataColumn(label: Text('Length', textAlign: TextAlign.center)),
        DataColumn(label: Text('Rating', textAlign: TextAlign.center)),
      ],
      rows: tracks.map((track) {
        final trackId = track['track_id'] ?? 0;
        return DataRow(
          cells: [
            DataCell(Center(child: Text(track['position'].toString()))),
            DataCell(Text(track['title'] ?? '')),
            DataCell(Center(child: Text(formatDuration(track['duration'] ?? 0)))),
            DataCell(
              Center(
                child: SizedBox(
                  width: 150,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: ratings[trackId] ?? 0.0,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: ratings[trackId]?.toStringAsFixed(0),
                          onChanged: (newRating) {
                            _updateRating(trackId, newRating);
                          },
                        ),
                      ),
                      Text(
                        ratings[trackId]?.toStringAsFixed(0) ?? '0',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
