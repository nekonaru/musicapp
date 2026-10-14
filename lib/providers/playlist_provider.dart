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
    try {
      // DB memakai ConflictAlgorithm.ignore sehingga duplikat tidak melempar
      // error SQLite - cek eksplisit supaya UI dapat pesan yang jelas.
      final current = await DBHelper.instance.getSongsInPlaylist(playlistId);
      if (current.any((s) => s.id == songId)) {
        throw Exception('Lagu sudah ada di playlist ini');
      }
      await DBHelper.instance.addSongToPlaylist(playlistId, songId);
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('UNIQUE')) {
        throw Exception('Lagu sudah ada di playlist ini');
      }
      rethrow;
    }
  }

  Future<void> removeSong(int playlistId, int songId) async {
    try {
      await DBHelper.instance.removeSongFromPlaylist(playlistId, songId);
      notifyListeners();
    } catch (e) {
      throw Exception('Gagal menghapus lagu dari playlist: $e');
    }
  }

  Future<List<Song>> songsIn(int playlistId) =>
      DBHelper.instance.getSongsInPlaylist(playlistId);

  Future<void> reorder(int playlistId, List<int> songIdsInOrder) async {
    try {
      await DBHelper.instance.reorderPlaylistSongs(playlistId, songIdsInOrder);
      notifyListeners();
    } catch (e) {
      throw Exception('Gagal menyimpan urutan playlist: $e');
    }
  }
}
