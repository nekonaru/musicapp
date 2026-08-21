import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/db_helper.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Map<String, dynamic>> playlists = [];

  Future<void> load() async {
    playlists = await DBHelper.instance.getPlaylists();
    notifyListeners();
  }

  Future<void> create(String name) async {
    await DBHelper.instance.createPlaylist(name);
    await load();
  }

  Future<void> delete(int id) async {
    await DBHelper.instance.deletePlaylist(id);
    await load();
  }

  Future<void> addSong(int playlistId, int songId) async {
    await DBHelper.instance.addSongToPlaylist(playlistId, songId);
  }

  Future<void> removeSong(int playlistId, int songId) async {
    await DBHelper.instance.removeSongFromPlaylist(playlistId, songId);
  }

  Future<List<Song>> songsIn(int playlistId) =>
      DBHelper.instance.getSongsInPlaylist(playlistId);

  Future<void> reorder(int playlistId, List<int> songIdsInOrder) =>
      DBHelper.instance.reorderPlaylistSongs(playlistId, songIdsInOrder);
}
