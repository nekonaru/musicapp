# Pemutar Musik Offline

Aplikasi Flutter pemutar musik offline dengan auto-metadata, lirik, dashboard analitik, playlist, dan lainnya.

## Fitur
- Scan & putar musik offline dari storage HP
- Auto-fetch metadata (judul, artis, album art, genre, region) via iTunes Search API
- Auto-fetch lirik via lyrics.ovh
- Dashboard: grafik jam dengar 7 hari terakhir, top lagu, top artis, distribusi genre & region
- Folder lagu (browse by folder asal file)
- Playlist, favorit, riwayat baru diputar
- Shuffle, repeat (off/all/one), sleep timer
- Edit metadata manual (judul, artis, album, genre, region, lirik)
- Hapus lagu dari library (file asli tidak terhapus)

## Cara Menjalankan

1. **Install Flutter SDK** (jika belum): https://docs.flutter.dev/get-started/install
2. Masuk ke folder project:
   ```bash
   cd music_app
   flutter pub get
   ```
3. Colok HP Android (aktifkan USB debugging) atau jalankan emulator, lalu:
   ```bash
   flutter run
   ```

## Setup Permission Android (penting!)

Buka `android/app/src/main/AndroidManifest.xml`, tambahkan di dalam tag `<manifest>` (sebelum `<application>`):

```xml
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

Untuk background audio playback (musik tetap jalan saat app di-minimize), ikuti setup tambahan
package `audio_service`: https://pub.dev/packages/audio_service (perlu edit `AndroidManifest.xml`
untuk mendaftarkan `AudioService` sebagai foreground service — sudah ada dependency-nya di
`pubspec.yaml`, tinggal ikuti langkah "Android" di dokumentasi package tersebut).

## Struktur Project

```
lib/
  models/song.dart          -> model data Song & ListeningEntry
  services/
    db_helper.dart          -> semua query SQLite (lagu, playlist, riwayat, folder)
    library_scanner.dart    -> scan file musik dari device
    metadata_service.dart   -> fetch metadata/album art/lirik otomatis
    player_service.dart     -> logic playback: shuffle, repeat, sleep timer, log riwayat
  providers/                -> state management (Provider)
  screens/                  -> semua UI (library, dashboard, player, folder, playlist, favorit)
  main.dart                 -> entry point
```

## Sumber Data Eksternal (gratis, tanpa API key)
- **Metadata & album art**: iTunes Search API (`itunes.apple.com/search`)
- **Lirik**: lyrics.ovh API

Kalau lagu tidak ditemukan di API (misal lagu lokal/indie), metadata & lirik bisa
diisi manual lewat menu "Edit Metadata" di tiap lagu.

## Catatan
- Region asal lagu ditebak dari data negara di iTunes API. Karena heuristik sederhana,
  hasilnya kadang perlu dikoreksi manual — bisa diedit lewat "Edit Metadata".
- Semua data (riwayat dengar, playlist, favorit, metadata) disimpan lokal di SQLite,
  jadi tetap tersedia offline setelah metadata pertama kali di-fetch.
