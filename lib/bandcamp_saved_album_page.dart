import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_data.dart';
import 'bandcamp_parser.dart'; // Asegúrate de importar el archivo actualizado de bandcamp_parser.dart
import 'footer.dart';
import 'app_theme.dart';

class BandcampSavedAlbumPage extends StatefulWidget {
  final dynamic album;

  BandcampSavedAlbumPage({Key? key, required this.album}) : super(key: key);

  @override
  _BandcampSavedAlbumPageState createState() => _BandcampSavedAlbumPageState();
}

class _BandcampSavedAlbumPageState extends State<BandcampSavedAlbumPage> {
  List<Map<String, dynamic>> tracks = [];
  Map<int, double> ratings = {};
  double averageRating = 0.0;
  int albumDurationMillis = 0;
  bool isLoading = true;
  DateTime? datePublished;

  @override
  void initState() {
    super.initState();
    print('Init State: Starting to fetch tracks for album ${widget.album['collectionId']}');
    _fetchTracks();
  }

  void _fetchTracks() async {
    final url = Uri.parse(widget.album['url']);
    try {
      final response = await http.get(url);
      final jsonData = BandcampParser.extractBandcampJson(response.body); // Utiliza extractBandcampJson correctamente
      final extractedTracks = BandcampParser.extractTracks(jsonData);
      final datePublishedData = _extractDatePublishedFromJson(jsonData); // Extrae la fecha de publicación
      setState(() {
        tracks = extractedTracks;
        extractedTracks.forEach((track) => ratings[track['track_id']] = 0.0); // Asegúrate de utilizar 'track_id' en lugar de 'trackId'
        calculateAlbumDuration();
        _loadSavedRatings();
        isLoading = false;
        datePublished = datePublishedData;
      });
      print('Tracks fetched successfully: $extractedTracks');
    } catch (error) {
      print('Error fetching tracks: $error');
    }
  }

  DateTime? _extractDatePublishedFromJson(Map<String, dynamic> jsonData) {
    // Implementa lógica para extraer la fecha de publicación del JSON
    // Aquí asumimos que la fecha de publicación está en una estructura adecuada dentro de `jsonData`
    // Reemplaza este código con la lógica específica de tu implementación
    return DateTime.now(); // Aquí deberías devolver la fecha de publicación adecuada
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

  void _loadSavedRatings() async {
    print('Loading saved ratings for album ${widget.album['collectionId']}');
    List<Map<String, dynamic>> savedRatings =
        await UserData.getSavedAlbumRatings(widget.album['collectionId']);
    setState(() {
      for (var rating in savedRatings) {
        ratings[rating['track_id']] = rating['rating']; // Asegúrate de utilizar 'track_id' en lugar de 'trackId'
      }
      calculateAverageRating();
    });
    print('Saved ratings loaded: $ratings');
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

  void _updateRating(int trackId, double newRating) async {
    setState(() {
      ratings[trackId] = newRating;
      calculateAverageRating();
    });

    await UserData.saveRating(widget.album['collectionId'], trackId, newRating);
    print('Updated rating for trackId $trackId: $newRating');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album['collectionName']),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        widget.album['artworkUrl100']
                            .replaceAll('100x100', '600x600'),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Artist: ",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${widget.album['artistName']}"),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Album: ",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${widget.album['collectionName']}"),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Date Published: ",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                datePublished != null
                                    ? "${DateFormat('dd-MM-yyyy').format(datePublished!)}"
                                    : 'Unknown Date',
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Duration: ",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(formatDuration(albumDurationMillis)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Rating: ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              Text(averageRating.toStringAsFixed(2), style: TextStyle(fontSize: 20)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Divider(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Track No.')),
                          DataColumn(label: Text('Title')),
                          DataColumn(label: Text('Length')),
                          DataColumn(label: Text('Rating', textAlign: TextAlign.center)),
                        ],
                        rows: tracks.map((track) => DataRow(
                          cells: [
                            DataCell(Text(track['track_id'].toString())), // Asegúrate de utilizar 'track_id' en lugar de 'trackId'
                            DataCell(
                              Tooltip(
                                message: track['title'],
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.3,
                                  ),
                                  child: Text(
                                    track['title'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(formatDuration(track['duration'] as int))),
                            DataCell(Container(
                              width: 150,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      min: 0,
                                      max: 10,
                                      divisions: 10,
                                      value: ratings[track['track_id']] ?? 0.0, // Asegúrate de utilizar 'track_id' en lugar de 'trackId'
                                      onChanged: (newRating) {
                                        _updateRating(track['track_id'], newRating); // Asegúrate de utilizar 'track_id' en lugar de 'trackId'
                                      },
                                    ),
                                  ),
                                  Text((ratings[track['track_id']] ?? 0.0)
                                      .toStringAsFixed(0)),
                                ],
                              ),
                            )),
                          ],
                        )).toList(),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _launchRateYourMusic,
                      child: Text(
                        'RateYourMusic.com',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkTheme.colorScheme.primary
                            : AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Footer(),
    );
  }

  String formatDuration(int millis) {
    int seconds = (millis ~/ 1000) % 60;
    int minutes = (millis ~/ 1000) ~/ 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
