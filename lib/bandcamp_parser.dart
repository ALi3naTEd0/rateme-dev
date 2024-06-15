import 'dart:convert';
import 'package:html/parser.dart' as parser;

class BandcampParser {
  static Map<String, dynamic> extractBandcampJson(String responseBody) {
    try {
      final document = parser.parse(responseBody);
      final script = document.querySelector('script[type="application/ld+json"]');
      if (script != null) {
        final jsonString = script.text;
        final jsonData = json.decode(jsonString);
        return jsonData;
      } else {
        print('No JSON-LD found in the page');
        return {};
      }
    } catch (e) {
      print('Error parsing JSON-LD: $e');
      return {};
    }
  }

  static List<Map<String, dynamic>> extractTracks(Map<String, dynamic> jsonData) {
    List<Map<String, dynamic>> tracks = [];
    try {
      if (jsonData.containsKey('trackinfo')) {
        final trackInfo = jsonData['trackinfo'] as List;
        tracks = trackInfo.map((track) => {
          'track_id': track['track_id'],
          'title': track['title'],
          'duration': track['duration'],
          'datePublished': track['datePublished'],
          // Add other necessary fields as needed
        }).toList();
      }
    } catch (e) {
      print('Error extracting tracks: $e');
    }
    return tracks;
  }
}
