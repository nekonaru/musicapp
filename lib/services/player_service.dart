import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'db_helper.dart';

enum RepeatMode { off, all, one }

class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  // Player kedua khusus untuk crossfade (dinyalakan bergantian dengan _player)
  final AudioPlayer _crossfadePlayer = AudioPlayer();
  bool _usingCrossfadePlayer = false;

  // _queue: daftar lagu asli (urutan asal, tidak berubah oleh shuffle)
  List<Song> _queue = [];
  // _playOrder: urutan pemutaran sebenarnya (berisi index ke _queue).
  // Kalau shuffle mati: [0,1,2,...]. Kalau shuffle aktif: acak sekali, tidak berubah tiap next/previous.
  List<int> _playOrder = [];
  int _posInOrder = 0;

  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool crossfadeEnabled = false;
  static const Duration crossfadeDuration = Duration(seconds: 3);

  Timer? _sleepTimer;
  DateTime? sleepTimerEndTime;
  int? sleepSongsRemaining;
  bool _finishCurrentSongOnSleep = false;
  bool _pendingSleepStop = false;
  String? lastError;

  DateTime? _playStartedAt;
  int _accumulatedListenedMs = 0;

  StreamSubscription? _positionSub;
  bool _crossfadeTriggeredForCurrent = false;
  bool _crossfadeCancelled = false;

  /// Player yang SEDANG terdengar sekarang (berganti tiap kali crossfade selesai)
  AudioPlayer get _activePlayer => _usingCrossfadePlayer ? _crossfadePlayer : _player;
  /// Player "cadangan" yang dipakai buat fade-in lagu berikutnya
  AudioPlayer get _fadeTargetPlayer => _usingCrossfadePlayer ? _player : _crossfadePlayer;

  AudioPlayer get player => _activePlayer;

  Song? get currentSong {
    if (_playOrder.isEmpty || _posInOrder < 0 || _posInOrder >= _playOrder.length) return null;
    return _queue[_playOrder[_posInOrder]];
  }

  bool get isShuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;

  /// Antrean sesuai urutan pemutaran sebenarnya (dipakai halaman Antrean)
  List<Song> get queue => _playOrder.map((i) => _queue[i]).toList();
  int get currentIndex => _posInOrder;

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_usingCrossfadePlayer) {
        _logListening();
        _onTrackFinished();
      }
    });
    _crossfadePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _usingCrossfadePlayer) {
        _logListening();
        _onTrackFinished();
      }
    });
    _positionSub = _activePlayer.positionStream.listen(_maybeStartCrossfade);
  }

  void _maybeStartCrossfade(Duration position) {
    // Guard cuma cek "sudah dipicu untuk lagu ini", TIDAK lagi cek _usingCrossfadePlayer -
    // supaya crossfade tetap bisa terpicu berulang kali untuk setiap lagu, bukan cuma sekali.
    if (!crossfadeEnabled || _crossfadeTriggeredForCurrent) return;
    final dur = _activePlayer.duration;
    if (dur == null) return;
    final remaining = dur - position;
    if (remaining <= crossfadeDuration && remaining > Duration.zero) {
      _crossfadeTriggeredForCurrent = true;
      _startCrossfadeToNext();
    }
  }

  Future<void> _startCrossfadeToNext() async {
    if (_playOrder.isEmpty) return;
    final nextPos = _computeNextPosition();
    if (nextPos == null) return;
    final nextSong = _queue[_playOrder[nextPos]];

    // Pakai getter dinamis - bukan hardcode _player/_crossfadePlayer - supaya
    // benar untuk crossfade KE BERAPA PUN kalinya, bukan cuma yang pertama.
    final outgoing = _activePlayer;
    final incoming = _fadeTargetPlayer;
    _crossfadeCancelled = false;

    try {
      await incoming.setFilePath(nextSong.filePath);
      await incoming.setVolume(0);
      await incoming.play();

      const steps = 20;
      final stepDuration = crossfadeDuration ~/ steps;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(stepDuration);
        if (_crossfadeCancelled) break; // user pencet next/previous di tengah crossfade
        final v = i / steps;
        incoming.setVolume(v);
        outgoing.setVolume(1 - v);
      }
      if (_crossfadeCancelled) {
        // Dibatalkan di tengah jalan - bersihkan player cadangan, jangan lanjut swap
        await incoming.pause();
        await incoming.setVolume(1);
        await outgoing.setVolume(1);
        _crossfadeTriggeredForCurrent = false;
        return;
      }

      await outgoing.pause();
      await outgoing.setVolume(1);

      // PENTING: catat riwayat dengar lagu LAMA dulu (pakai currentSong yang masih
      // menunjuk ke lagu lama, sebelum _posInOrder berpindah), baru reset jam mulai
      // untuk lagu BARU - supaya listening_entries tidak salah atribusi/durasi dobel.
      _logListening();
      _usingCrossfadePlayer = !_usingCrossfadePlayer;
      _posInOrder = nextPos;
      _playStartedAt = DateTime.now();
      _accumulatedListenedMs = 0;
      _crossfadeTriggeredForCurrent = false;
      await DBHelper.instance.markPlayed(nextSong.id);

      _positionSub?.cancel();
      _positionSub = _activePlayer.positionStream.listen(_maybeStartCrossfade);

      notifyListeners();
    } catch (e) {
      debugPrint('Crossfade gagal, lanjut normal: $e');
      _crossfadeTriggeredForCurrent = false;
    }
  }

  int? _computeNextPosition() {
    // RepeatMode.one harus dicek DULUAN sebelum kondisi lainnya,
    // supaya crossfade juga mengulang lagu yang sama bukan maju ke berikutnya.
    if (_repeatMode == RepeatMode.one) return _posInOrder;
    if (_posInOrder < _playOrder.length - 1) return _posInOrder + 1;
    if (_repeatMode == RepeatMode.all) return 0;
    return null;
  }

  /// Mulai memutar daftar lagu baru. Ini SELALU mengganti seluruh antrean
  /// jadi cuma isi `songs` (dipakai dari halaman Semua Lagu / Folder / Playlist / Favorit
  /// masing-masing, jadi antrean otomatis terbatas sesuai sumbernya).
  Future<void> setQueueAndPlay(List<Song> songs, int startIndex) async {
    _logListening();
    _crossfadeCancelled = true;
    _crossfadeTriggeredForCurrent = false;
    _usingCrossfadePlayer = false;
    await _crossfadePlayer.pause();
    _queue = List.of(songs);

    if (_shuffle) {
      _playOrder = _buildShuffledOrder(_queue.length, startIndex);
      _posInOrder = 0;
    } else {
      _playOrder = List.generate(_queue.length, (i) => i);
      _posInOrder = startIndex;
    }

    notifyListeners(); // supaya mini-player langsung muncul, tanpa nunggu file selesai load
    await _playCurrent();
    notifyListeners();
  }

  List<int> _buildShuffledOrder(int length, int startIndex) {
    final indices = List.generate(length, (i) => i);
    indices.remove(startIndex);
    indices.shuffle(Random());
    return [startIndex, ...indices];
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;
    try {
      await _player.setFilePath(song.filePath);
      await _player.setVolume(1);
    } catch (e) {
      debugPrint('Gagal memutar lagu: $e');
      lastError = 'Gagal memutar "${song.title}": $e';
      notifyListeners();
      return;
    }
    await _player.play();
    _playStartedAt = DateTime.now();
    _accumulatedListenedMs = 0;
    await DBHelper.instance.markPlayed(song.id);
    lastError = null;
    // Pasang ulang listener posisi ke player yang sekarang aktif, supaya
    // crossfade tetap terpicu untuk lagu-lagu berikutnya juga (bukan cuma sekali).
    _positionSub?.cancel();
    _positionSub = player.positionStream.listen(_maybeStartCrossfade);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      _logListening();
      await player.pause();
    } else {
      _playStartedAt = DateTime.now();
      await player.play();
    }
    notifyListeners();
  }

  /// Lagu berikutnya SESUAI urutan antrean (_playOrder). Kalau shuffle aktif,
  /// urutan acaknya sudah ditentukan sekali di awal - next tidak mengacak ulang.
  Future<void> next() async {
    _logListening();
    _crossfadeCancelled = true;
    await _crossfadePlayer.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (_posInOrder < _playOrder.length - 1) {
      _posInOrder++;
    } else if (_repeatMode == RepeatMode.all) {
      _posInOrder = 0;
    } else {
      return; // sudah di lagu terakhir, tidak ada repeat
    }
    await _playCurrent();
  }

  /// Lagu sebelumnya SESUAI urutan antrean - benar-benar mundur satu posisi
  /// di _playOrder, bukan lagu acak baru.
  Future<void> previous() async {
    _logListening();
    _crossfadeCancelled = true;
    await _crossfadePlayer.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (_posInOrder > 0) {
      _posInOrder--;
    } else if (_repeatMode == RepeatMode.all) {
      _posInOrder = _playOrder.length - 1;
    } else {
      _posInOrder = 0;
    }
    await _playCurrent();
  }

  Future<void> playAtQueueIndex(int posInOrder) async {
    if (posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _logListening();
    _crossfadeCancelled = true;
    await _crossfadePlayer.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    _posInOrder = posInOrder;
    await _playCurrent();
  }

  void playNext(Song song) {
    if (_queue.isEmpty) {
      setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    _playOrder.insert(_posInOrder + 1, _queue.length - 1);
    notifyListeners();
  }

  void addToQueueEnd(Song song) {
    if (_queue.isEmpty) {
      setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    _playOrder.add(_queue.length - 1);
    notifyListeners();
  }

  /// ID slot antrean (index asli di _queue) untuk tiap posisi di _playOrder -
  /// dipakai UI supaya bisa hapus lagu yang BENAR meski list sempat berubah
  /// di tengah proses swipe (index posisi biasa bisa jadi basi, ID slot ini tidak).
  List<int> get queueSlotIds => List.unmodifiable(_playOrder);

  /// Hapus dari antrean (posisi di _playOrder, bukan currently playing)
  void removeFromQueue(int posInOrder) {
    if (posInOrder == _posInOrder || posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _playOrder.removeAt(posInOrder);
    if (posInOrder < _posInOrder) _posInOrder--;
    // Compact _queue: buang entri yang sudah tidak direferensikan oleh _playOrder manapun
    // supaya _queue tidak terus membesar sepanjang sesi tanpa restart app.
    _compactQueue();
    notifyListeners();
  }

  /// Buang entri _queue yang sudah tidak ada di _playOrder.
  /// Setelah compact, remap semua index di _playOrder ke posisi baru.
  void _compactQueue() {
    final used = _playOrder.toSet();
    if (used.length == _queue.length) return; // tidak ada yang perlu dibuang

    // Buat mapping index lama → index baru
    final Map<int, int> remap = {};
    int newIdx = 0;
    final newQueue = <Song>[];
    for (int oldIdx = 0; oldIdx < _queue.length; oldIdx++) {
      if (used.contains(oldIdx)) {
        remap[oldIdx] = newIdx++;
        newQueue.add(_queue[oldIdx]);
      }
    }
    _queue = newQueue;
    _playOrder = _playOrder.map((old) => remap[old]!).toList();
  }

  /// Hapus dari antrean berdasarkan slot ID (stabil), bukan posisi index biasa -
  /// aman dipanggil dari swipe-to-dismiss walau list sempat berubah di tengah jalan.
  void removeQueueSlot(int slotId) {
    final pos = _playOrder.indexOf(slotId);
    if (pos == -1) return; // sudah dihapus/berubah duluan, aman diabaikan
    removeFromQueue(pos);
  }

  /// Drag reorder di halaman Antrean - yang diubah urutannya adalah _playOrder
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playOrder.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= _playOrder.length) return;

    final moved = _playOrder.removeAt(oldIndex);
    _playOrder.insert(newIndex, moved);

    if (oldIndex == _posInOrder) {
      _posInOrder = newIndex;
    } else if (oldIndex < _posInOrder && newIndex >= _posInOrder) {
      _posInOrder--;
    } else if (oldIndex > _posInOrder && newIndex <= _posInOrder) {
      _posInOrder++;
    }
    notifyListeners();
  }

  double get playbackSpeed => _player.speed;

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    await _crossfadePlayer.setSpeed(speed);
    notifyListeners();
  }

  /// Toggle shuffle TANPA mengubah lagu yang sedang diputar - cuma
  /// menyusun ulang urutan lagu-lagu SETELAHNYA (kalau ON) atau
  /// mengembalikan ke urutan asli (kalau OFF).
  void toggleShuffle() {
    setShuffle(!_shuffle);
  }

  /// Set status shuffle secara eksplisit (bukan toggle) - dipakai tombol
  /// "Acak" supaya selalu MENGAKTIFKAN shuffle, tidak pernah mematikannya.
  void setShuffle(bool value) {
    _shuffle = value;
    final song = currentSong;
    if (song == null) {
      notifyListeners();
      return;
    }
    final currentQueueIndex = _playOrder[_posInOrder];

    if (_shuffle) {
      final rest = List.generate(_queue.length, (i) => i)..remove(currentQueueIndex);
      rest.shuffle(Random());
      _playOrder = [currentQueueIndex, ...rest];
      _posInOrder = 0;
    } else {
      _playOrder = List.generate(_queue.length, (i) => i);
      _posInOrder = currentQueueIndex;
    }
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void setCrossfadeEnabled(bool value) {
    crossfadeEnabled = value;
    notifyListeners();
  }

  /// Timer tidur berbasis WAKTU dengan hitung mundur.
  /// [finishCurrentSong] true = tidak langsung stop pas waktu habis, tapi
  /// tunggu lagu yang sedang diputar selesai dulu baru berhenti.
  void setSleepTimer(Duration duration, {bool finishCurrentSong = false}) {
    _sleepTimer?.cancel();
    sleepSongsRemaining = null; // mode waktu & mode lagu saling eksklusif
    sleepTimerEndTime = DateTime.now().add(duration);
    _finishCurrentSongOnSleep = finishCurrentSong;
    _sleepTimer = Timer(duration, () async {
      sleepTimerEndTime = null;
      if (_finishCurrentSongOnSleep) {
        _pendingSleepStop = true; // ditangani di _onTrackFinished()
      } else {
        _logListening();
        // Pause KEDUA player supaya musik pasti berhenti walau sedang crossfade
        await _player.pause();
        await _crossfadePlayer.pause();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// Timer tidur berbasis JUMLAH LAGU - berhenti otomatis setelah N lagu
  /// (dihitung dari lagu yang sedang diputar sekarang, termasuk).
  void setSleepTimerBySongs(int songCount) {
    _sleepTimer?.cancel();
    sleepTimerEndTime = null; // mode waktu & mode lagu saling eksklusif
    sleepSongsRemaining = songCount;
    notifyListeners();
  }

  Duration? get sleepTimerRemaining {
    if (sleepTimerEndTime == null) return null;
    final remaining = sleepTimerEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerEndTime = null;
    sleepSongsRemaining = null;
    _pendingSleepStop = false;
    notifyListeners();
  }

  void _onTrackFinished() {
    // Mode hitung jumlah lagu: kurangi 1, berhenti kalau sudah habis
    if (sleepSongsRemaining != null) {
      sleepSongsRemaining = sleepSongsRemaining! - 1;
      if (sleepSongsRemaining! <= 0) {
        sleepSongsRemaining = null;
        _logListening();
        _player.pause();
        _crossfadePlayer.pause();
        notifyListeners();
        return;
      }
    }
    // Mode waktu dengan "selesaikan lagu terakhir": lagu barusan itu yang terakhir
    if (_pendingSleepStop) {
      _pendingSleepStop = false;
      _logListening();
      _player.pause();
      _crossfadePlayer.pause();
      notifyListeners();
      return;
    }

    if (_repeatMode == RepeatMode.one) {
      _usingCrossfadePlayer = false;
      _crossfadeTriggeredForCurrent = false;
      _playCurrent();
      return;
    }
    next();
  }

  void _logListening() {
    if (_playStartedAt == null || currentSong == null) return;
    final elapsed = DateTime.now().difference(_playStartedAt!).inMilliseconds;
    _accumulatedListenedMs += elapsed;
    _playStartedAt = null;

    if (_accumulatedListenedMs > 1000) {
      DBHelper.instance.addListeningEntry(ListeningEntry(
        songId: currentSong!.id,
        timestamp: DateTime.now(),
        listenedMs: _accumulatedListenedMs,
      ));
    }
    _accumulatedListenedMs = 0;
  }

  Future<void> dispose() async {
    _logListening();
    _positionSub?.cancel();
    await _player.dispose();
    await _crossfadePlayer.dispose();
  }
}
