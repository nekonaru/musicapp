// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsAppearance => 'Tampilan';

  @override
  String get settingsFollowSystem => 'Ikuti sistem';

  @override
  String get settingsLight => 'Terang';

  @override
  String get settingsDark => 'Gelap';

  @override
  String get settingsAccentColor => 'Warna Aksen';

  @override
  String get settingsAccentPurple => 'Ungu';

  @override
  String get settingsAccentBlue => 'Biru';

  @override
  String get settingsAccentTeal => 'Teal';

  @override
  String get settingsAccentGreen => 'Hijau';

  @override
  String get settingsAccentOrange => 'Oranye';

  @override
  String get settingsAccentRed => 'Merah';

  @override
  String get settingsAccentDeepPurple => 'Ungu Tua';

  @override
  String get settingsAccentPink => 'Pink';

  @override
  String get settingsAccentCyan => 'Cyan';

  @override
  String get settingsAccentLightGreen => 'Hijau Muda';

  @override
  String get settingsPlayback => 'Pemutaran';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsCrossfadeSubtitle =>
      'Transisi antar lagu tanpa jeda (3 detik)';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsEqualizerNote =>
      'Preset ini hanya tampilan visualisasi, belum mengubah suara aktual. Pilihan disimpan antar sesi.';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get settingsScanFiles => 'Pindai File Musik';

  @override
  String get settingsScanFilesSubtitle =>
      'Cek file musik baru/dihapus di HP (tanpa internet)';

  @override
  String get settingsScanMissing => 'Scan Metadata yang Belum Ada';

  @override
  String get settingsScanMissingSubtitle =>
      'Ambil judul/artis/cover dari internet untuk lagu baru';

  @override
  String settingsScanProgress(int progress, int total) {
    return 'Memproses $progress/$total...';
  }

  @override
  String get settingsRescanAll => 'Scan Ulang Semua Metadata';

  @override
  String get settingsRescanAllSubtitle =>
      'Ambil ulang dari internet untuk SEMUA lagu';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get settingsAboutVersion => 'v1.6.0 · by Niko';

  @override
  String get settingsRescanTitle => 'Scan Ulang Semua';

  @override
  String settingsRescanMessage(int count) {
    return 'Ambil ulang metadata untuk semua $count lagu dari internet? Ini butuh waktu lebih lama.';
  }

  @override
  String get settingsRescanStart => 'Mulai';

  @override
  String get languageSection => 'Bahasa';

  @override
  String get languageSubtitle => 'Bahasa aplikasi';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Batal';

  @override
  String get retry => 'Coba lagi';

  @override
  String get close => 'Tutup';

  @override
  String get save => 'Simpan';

  @override
  String get delete => 'Hapus';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Hapus';

  @override
  String get add => 'Tambah';

  @override
  String get create => 'Buat';

  @override
  String get search => 'Cari';

  @override
  String get loading => 'Memuat...';

  @override
  String get error => 'Terjadi kesalahan';

  @override
  String get empty => 'Belum ada apa-apa';

  @override
  String get confirm => 'Konfirmasi';

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get unknown => 'Tidak diketahui';

  @override
  String get failed => 'Gagal';

  @override
  String get corePlayFailed => 'Gagal memutar';

  @override
  String get coreScanFailed => 'Gagal memindai';

  @override
  String get coreUpdateFavoritesFailed => 'Gagal mengubah favorit';

  @override
  String get coreSongAlreadyInPlaylist => 'Lagu sudah ada di playlist ini';

  @override
  String get coreRemoveFromPlaylistFailed =>
      'Gagal menghapus lagu dari playlist';

  @override
  String get coreSavePlaylistOrderFailed => 'Gagal menyimpan urutan playlist';

  @override
  String get corePermissionDenied => 'Izin akses musik ditolak';

  @override
  String get coreSongs => 'lagu';

  @override
  String playlistLoadFailed(String error) {
    return 'Gagal memuat playlist: $error';
  }

  @override
  String playlistReorderFailed(String error) {
    return 'Gagal menyimpan urutan: $error';
  }

  @override
  String playlistRemoveFailed(String error) {
    return 'Gagal menghapus lagu: $error';
  }

  @override
  String get playlistSortCustom => 'Urutan kustom';

  @override
  String get playlistSortTitleAZ => 'Judul A-Z';

  @override
  String get playlistSortTitleZA => 'Judul Z-A';

  @override
  String get playlistSortArtistAZ => 'Artis A-Z';

  @override
  String get playlistEmpty => 'Playlist ini masih kosong';

  @override
  String playlistSummary(int count, String duration) {
    return '$count lagu · $duration';
  }

  @override
  String get playlistSearchHint => 'Cari di playlist ini...';

  @override
  String get playlistPlay => 'Mulai Putar';

  @override
  String get playlistShuffle => 'Acak';

  @override
  String get playlistReorderHint => 'Tahan dan geser untuk mengatur urutan';

  @override
  String get playlistNoResults => 'Lagu tidak ditemukan';

  @override
  String historyLoadFailed(String error) {
    return 'Gagal memuat riwayat: $error';
  }

  @override
  String get historyEmpty => 'Belum ada riwayat pemutaran';

  @override
  String get dashboardLoadFailedTitle => 'Gagal memuat dashboard';

  @override
  String get dashboardRetry => 'Coba Lagi';

  @override
  String get dashboardEmptyTitle => 'Dashboard kosong';

  @override
  String get dashboardEmptySubtitle =>
      'Statistik pendengaran akan muncul setelah kamu mulai memutar lagu.';

  @override
  String get dashboardTotalSongsLibrary => 'Total lagu di library';

  @override
  String get dashboardTotalSongs => 'Total lagu';

  @override
  String get dashboardTotalListened => 'Total didengar';

  @override
  String get dashboardThisMonth => 'Bulan ini';

  @override
  String dashboardHoursValue(String hours) {
    return '$hours jam';
  }

  @override
  String get dashboardListeningWeekTitle => 'Jam Dengar 7 Hari Terakhir';

  @override
  String dashboardWeekTotal(String hours) {
    return '$hours jam total';
  }

  @override
  String get dashboardTopSongs => 'Top 5 Lagu';

  @override
  String dashboardUnknownSong(int id) {
    return 'Lagu #$id';
  }

  @override
  String dashboardPlayCount(int count) {
    return '${count}x diputar';
  }

  @override
  String dashboardPlayFailed(String error) {
    return 'Gagal memutar lagu: $error';
  }

  @override
  String get dashboardTopArtists => 'Top 5 Artis';

  @override
  String get dashboardGenreTitle => 'Distribusi Genre';

  @override
  String dashboardGenreCount(int count) {
    return '$count genre';
  }

  @override
  String get dashboardNeverPlayedTitle => 'Belum Pernah Diputar';

  @override
  String dashboardSongCount(int count) {
    return '$count lagu';
  }

  @override
  String dashboardNeverPlayedSubtitle(int count) {
    return '$count lagu di library kamu belum pernah diputar.';
  }

  @override
  String get dashboardPlayAll => 'Putar Semua';

  @override
  String get dashboardWeekActivityTitle => 'Aktivitas Minggu Ini';

  @override
  String get dashboardNoWeekActivity => 'Belum ada aktivitas minggu ini.';

  @override
  String dashboardActiveDays(int count) {
    return '$count dari 7 hari aktif mendengarkan';
  }

  @override
  String dashboardNeverPlayedSheetTitle(int count) {
    return '$count lagu belum pernah diputar';
  }

  @override
  String get dashboardDaySun => 'Min';

  @override
  String get dashboardDayMon => 'Sen';

  @override
  String get dashboardDayTue => 'Sel';

  @override
  String get dashboardDayWed => 'Rab';

  @override
  String get dashboardDayThu => 'Kam';

  @override
  String get dashboardDayFri => 'Jum';

  @override
  String get dashboardDaySat => 'Sab';

  @override
  String dashboardTooltipMinutes(int mins) {
    return '${mins}m';
  }

  @override
  String dashboardTooltipHours(String hours) {
    return '${hours}j';
  }

  @override
  String get editMetadataValidationEmpty =>
      'Judul, artis, dan album tidak boleh kosong';

  @override
  String editMetadataSaveFailed(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get editMetadataRescanTitle => 'Scan Ulang dari Internet?';

  @override
  String get editMetadataRescanMessage =>
      'Data dari internet akan menimpa edit manual Anda di form ini. Lanjutkan?';

  @override
  String get editMetadataRescanConfirm => 'Ya, Timpa';

  @override
  String editMetadataRescanFailed(String error) {
    return 'Gagal scan ulang: $error';
  }

  @override
  String get editMetadataRescanSuccess =>
      'Metadata berhasil diperbarui dari internet';

  @override
  String get editMetadataTitle => 'Edit Metadata';

  @override
  String get editMetadataFetching => 'Mengambil data...';

  @override
  String get editMetadataRescanButton => 'Scan Ulang dari Internet';

  @override
  String get editMetadataFieldTitle => 'Judul';

  @override
  String get editMetadataFieldArtist => 'Artis';

  @override
  String get editMetadataFieldAlbum => 'Album';

  @override
  String get editMetadataFieldGenre => 'Genre';

  @override
  String get editMetadataFieldRegion => 'Asal Region';

  @override
  String get editMetadataEditLyricsButton => 'Edit Lirik (halaman terpisah)';

  @override
  String get editMetadataSaveButton => 'Simpan Perubahan';

  @override
  String get editLyricsClipboardEmpty =>
      'Clipboard kosong, tidak ada teks untuk ditempel';

  @override
  String get editLyricsPasteTitle => 'Tempel Lirik';

  @override
  String get editLyricsPasteMessage =>
      'Sudah ada lirik di sini. Mau ditimpa (mulai dari nol) atau ditambahkan ke lirik yang ada?';

  @override
  String get editLyricsAppend => 'Tambahkan';

  @override
  String get editLyricsOverwrite => 'Timpa';

  @override
  String editLyricsSaveFailed(String error) {
    return 'Gagal menyimpan lirik: $error';
  }

  @override
  String get editLyricsTruncated =>
      'Lirik melebihi 100KB dan dipotong saat disimpan';

  @override
  String editLyricsTitle(String title) {
    return 'Edit Lirik: $title';
  }

  @override
  String get editLyricsPasteButton => 'Tempelkan';

  @override
  String get editLyricsSearchWeb => 'Cari di Web';

  @override
  String get editLyricsHint =>
      'Belum ada lirik. Tempel dari clipboard, cari di web, atau ketik manual di sini.';

  @override
  String get editLyricsSaveButton => 'Simpan Lirik';

  @override
  String get songOptionsPlayNext => 'Putar Berikutnya';

  @override
  String get songOptionsAddedPlayNext => 'Ditambahkan untuk diputar berikutnya';

  @override
  String get songOptionsAddToQueueEnd => 'Tambah ke Akhir Antrean';

  @override
  String get songOptionsAddedToQueue => 'Ditambahkan ke antrean';

  @override
  String get songOptionsAddFavorite => 'Tambah ke Favorit';

  @override
  String get songOptionsRemoveFavorite => 'Hapus dari Favorit';

  @override
  String songOptionsFavoriteFailed(String error) {
    return 'Gagal update favorit: $error';
  }

  @override
  String get songOptionsAddToPlaylist => 'Tambah ke Playlist';

  @override
  String get songOptionsRename => 'Ganti Nama Lagu';

  @override
  String get songOptionsEditMetadata => 'Edit Metadata';

  @override
  String get songOptionsRemoveFromPlaylist => 'Hapus dari Playlist Ini';

  @override
  String songOptionsRemoveFromPlaylistFailed(String error) {
    return 'Gagal hapus dari playlist: $error';
  }

  @override
  String get songOptionsRemovedFromPlaylist => 'Dihapus dari playlist ini saja';

  @override
  String get songOptionsDeleteFromLibrary => 'Hapus dari Library';

  @override
  String get songOptionsDeleteTitle => 'Hapus Lagu';

  @override
  String songOptionsDeleteConfirm(String title) {
    return 'Hapus \"$title\" dari Semua Lagu, Folder, Favorit, dan Playlist? File asli di HP tidak terhapus - lagu ini akan muncul lagi kalau folder di-scan ulang.';
  }

  @override
  String songOptionsDeleteFailed(String error) {
    return 'Gagal hapus lagu: $error';
  }

  @override
  String songOptionsRenameFailed(String error) {
    return 'Gagal ganti nama: $error';
  }

  @override
  String get songOptionsCreatePlaylist => 'Buat Playlist Baru';

  @override
  String get songOptionsPlaylistNameTitle => 'Nama Playlist';

  @override
  String songOptionsAddToPlaylistFailed(String error) {
    return 'Gagal tambah ke playlist: $error';
  }

  @override
  String songOptionsPlaylistCreated(String name) {
    return 'Playlist \"$name\" dibuat & lagu ditambahkan';
  }

  @override
  String songOptionsPlaylistExists(String name) {
    return 'Playlist \"$name\" sudah ada, pilih dari daftar';
  }

  @override
  String songOptionsCreatePlaylistFailed(String error) {
    return 'Gagal membuat playlist: $error';
  }

  @override
  String get librarySortBy => 'Urutkan berdasarkan';

  @override
  String get librarySortTitleAsc => 'Judul ↑';

  @override
  String get librarySortTitleDesc => 'Judul ↓';

  @override
  String get librarySortArtistAsc => 'Artis ↑';

  @override
  String get librarySortArtistDesc => 'Artis ↓';

  @override
  String get librarySortAlbumAsc => 'Album ↑';

  @override
  String get librarySortAlbumDesc => 'Album ↓';

  @override
  String get librarySortDateNewest => 'Tanggal ↑';

  @override
  String get librarySortDateOldest => 'Tanggal ↓';

  @override
  String get librarySortGenre => 'Genre ↑';

  @override
  String get libraryCreatePlaylistFirst => 'Buat playlist dulu di tab Koleksi';

  @override
  String get libraryChoosePlaylist => 'Pilih playlist';

  @override
  String libraryAddedToPlaylist(int count, String name) {
    return '$count lagu ditambahkan ke $name';
  }

  @override
  String librarySelectedCount(int count) {
    return '$count dipilih';
  }

  @override
  String get libraryAddToPlaylist => 'Tambah ke playlist';

  @override
  String get libraryAddToFavorites => 'Tambah ke favorit';

  @override
  String librarySongCount(int count) {
    return '$count lagu';
  }

  @override
  String librarySongCountDuration(int count, String duration) {
    return '$count lagu · $duration';
  }

  @override
  String get libraryScanMetadata => 'Scan metadata';

  @override
  String get libraryStartPlaying => 'Mulai Putar';

  @override
  String get libraryShuffle => 'Acak';

  @override
  String get libraryScanningMusic => 'Memindai musik...';

  @override
  String get libraryNoMusic => 'Belum ada musik';

  @override
  String get libraryScanMusic => 'Pindai Musik';

  @override
  String get libraryScanMissing => 'Scan yang Belum Ada Metadata';

  @override
  String get libraryRescanAll => 'Scan Ulang Semua';

  @override
  String libraryRescanConfirm(int count) {
    return 'Ambil ulang metadata untuk $count lagu?';
  }

  @override
  String get libraryStart => 'Mulai';

  @override
  String libraryPlayFailed(String error) {
    return 'Gagal memutar lagu: $error';
  }

  @override
  String get searchHint => 'Cari musik...';

  @override
  String get searchFilterSong => 'Lagu';

  @override
  String get searchFilterAlbum => 'Album';

  @override
  String get searchFilterArtist => 'Artis';

  @override
  String get searchFilterFolder => 'Folder';

  @override
  String get searchFilterGenre => 'Genre';

  @override
  String get searchPromptTitle => 'Cari musik kamu';

  @override
  String get searchPromptSubtitle => 'Ketik judul, artis, album, atau lainnya';

  @override
  String get searchNoResults => 'Tidak ada hasil';

  @override
  String searchNotFound(String query) {
    return '\"$query\" tidak ditemukan';
  }

  @override
  String searchResultCount(int count) {
    return '$count hasil';
  }

  @override
  String get searchOther => 'Lainnya';

  @override
  String get albumsEmpty => 'Belum ada data album.';

  @override
  String albumsCount(int count) {
    return '$count album';
  }

  @override
  String get collectionsNewPlaylist => 'Playlist Baru';

  @override
  String get collectionsPlaylistNameHint => 'Nama playlist';

  @override
  String get collectionsDeletePlaylist => 'Hapus Playlist';

  @override
  String collectionsDeleteConfirm(String name) {
    return 'Hapus \"$name\"?';
  }

  @override
  String collectionsDeletePlaylistConfirm(String name) {
    return 'Hapus playlist \"$name\"?';
  }

  @override
  String get collectionsFavorites => 'Favorit';

  @override
  String get collectionsRecentlyAdded => 'Baru ditambahkan';

  @override
  String get collectionsRecentlyPlayed => 'Baru diputar';

  @override
  String get collectionsMostPlayed => 'Paling sering diputar';

  @override
  String get collectionsRecentlyAddedTitle => 'Baru Ditambahkan';

  @override
  String get collectionsRecentlyPlayedTitle => 'Baru Diputar';

  @override
  String get collectionsMostPlayedTitle => 'Paling Sering Diputar';

  @override
  String get collectionsSortNameAsc => 'Nama ↑';

  @override
  String get collectionsSortNameDesc => 'Nama ↓';

  @override
  String collectionsPlaylistCount(int count) {
    return '$count daftar putar';
  }

  @override
  String collectionsPlaylistCountAlt(int count) {
    return '$count playlist';
  }

  @override
  String get collectionsNoPlaylists => 'Belum ada playlist';

  @override
  String get collectionsCreatePlaylist => 'Buat Playlist';

  @override
  String get collectionsFavoritesEmpty => 'Belum ada favorit';

  @override
  String get collectionsFavoritesHint =>
      'Tekan ikon hati pada lagu untuk menambahkan';

  @override
  String get collectionsRecentlyAddedEmpty =>
      'Belum ada lagu yang ditambahkan.';

  @override
  String get collectionsMostPlayedEmpty => 'Belum ada data pemutaran';

  @override
  String get collectionsMostPlayedHint =>
      'Mulai putar lagu untuk melihat statistik';

  @override
  String foldersLoadFailed(String error) {
    return 'Gagal memuat folder: $error';
  }

  @override
  String get foldersShownAgain => 'Folder ditampilkan lagi';

  @override
  String get foldersHidden => 'Folder disembunyikan dari library';

  @override
  String get foldersEmpty => 'Belum ada folder musik terdeteksi.';

  @override
  String foldersCount(int count) {
    return '$count folder';
  }

  @override
  String get foldersSortNameAsc => 'Nama ↑';

  @override
  String get foldersSortNameDesc => 'Nama ↓';

  @override
  String get foldersSortCount => 'Jumlah lagu';

  @override
  String get foldersSortCountShort => 'Jumlah';

  @override
  String get foldersHideHidden => 'Sembunyikan folder tersembunyi';

  @override
  String get foldersShowHidden => 'Tampilkan folder tersembunyi';

  @override
  String get foldersNoSongs => 'Tidak ada lagu';

  @override
  String get foldersAllScanned =>
      'Semua lagu di folder ini sudah pernah discan';

  @override
  String get foldersScanDone => 'Selesai scan metadata folder ini';

  @override
  String get foldersSortTitleAsc => 'Judul ↑';

  @override
  String get foldersSortTitleDesc => 'Judul ↓';

  @override
  String get foldersSortArtistAsc => 'Artis ↑';

  @override
  String get foldersSortDate => 'Tanggal ↑';

  @override
  String get artistsEmpty => 'Belum ada data artis.';

  @override
  String artistsCount(int count) {
    return '$count artis';
  }

  @override
  String get genresEmpty => 'Belum ada data genre.';

  @override
  String genresCount(int count) {
    return '$count genre';
  }

  @override
  String get homeLibrary => 'Perpustakaan';

  @override
  String get homeCollection => 'Koleksi';

  @override
  String get homeDashboard => 'Dashboard';

  @override
  String get homeTabSongs => 'Lagu';

  @override
  String get homeTabAlbums => 'Album';

  @override
  String get homeTabArtists => 'Artis';

  @override
  String get homeTabFolders => 'Folder';

  @override
  String get homeTabGenres => 'Genre';

  @override
  String get homeTabSettings => 'Pengaturan tab';

  @override
  String get homeTabReorderHint => 'Seret tab untuk mengubah urutan';

  @override
  String get homeReset => 'Atur Ulang';

  @override
  String get homeApply => 'Terapkan';

  @override
  String get homeMinOneTab => 'Minimal 1 tab harus aktif';

  @override
  String get homeSettings => 'Pengaturan';

  @override
  String homeLoadLibraryFailed(String error) {
    return 'Gagal memuat library: $error';
  }

  @override
  String get homePressAgainToExit => 'Tekan sekali lagi untuk keluar';

  @override
  String get playerPlaybackSpeed => 'Kecepatan Putar';

  @override
  String get playerCannotOpenBrowser => 'Tidak bisa membuka browser';

  @override
  String get playerSearchOpenFailed => 'Gagal membuka pencarian';

  @override
  String get playerLyricsFound => 'Lirik ditemukan!';

  @override
  String get playerLyricsNotFoundHint =>
      'Lirik tetap tidak ditemukan, coba tambah manual';

  @override
  String playerSongsRemaining(int count) {
    return '$count lagu lagi';
  }

  @override
  String get playerEmptyState => 'Belum ada lagu diputar';

  @override
  String get playerTapToReturnToCover => 'Ketuk untuk kembali ke cover';

  @override
  String get playerEditLyrics => 'Edit Lirik';

  @override
  String get playerLyricsNotFound => 'Lirik tidak ditemukan';

  @override
  String get playerTapHereToReturnToCover =>
      'Ketuk di sini untuk kembali ke cover';

  @override
  String get playerSearchOnGoogle => 'Cari di Google';

  @override
  String get playerAutoSearch => 'Cari Otomatis';

  @override
  String get playerAddManually => 'Tambah Manual';

  @override
  String get playerPrevious => 'Sebelumnya';

  @override
  String get playerNext => 'Berikutnya';

  @override
  String get playerFavorite => 'Favorit';

  @override
  String get playerAddToPlaylist => 'Tambah ke Playlist';

  @override
  String get playerSleepTimer => 'Timer Tidur';

  @override
  String get queueTitle => 'Antrean Putar';

  @override
  String get queueEmpty => 'Antrean kosong';

  @override
  String get queueReorderHint =>
      'Tahan-geser untuk urutkan · geser ke kiri untuk hapus';

  @override
  String get sleepTitle => 'Timer tidur';

  @override
  String get sleepSetTimeAboveZero => 'Set waktu lebih dari 0';

  @override
  String get sleepRemaining => 'tersisa';

  @override
  String get sleepFinishLastSong => 'Selesaikan lagu terakhir';

  @override
  String get sleepSongsRemaining => 'lagu tersisa';

  @override
  String get sleepStop => 'Berhenti';

  @override
  String get sleepTimeMode => 'Waktu';

  @override
  String get sleepSongMode => 'Lagu';

  @override
  String get sleepStart => 'Mulai';

  @override
  String get sleepSongUnit => 'lagu';

  @override
  String get sleepTimerStopped => 'Timer tidur dihentikan';
}
