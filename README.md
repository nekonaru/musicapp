<div align="center">

# 🎵 Pemutar Musik Offline

**Aplikasi pemutar musik offline berbasis Flutter dengan metadata otomatis, lirik, dan dashboard analitik pendengaran.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://github.com/nekonaru/musicapp)

</div>

---

## ✨ Fitur

### 🎧 Pemutaran
- Scan & putar musik offline langsung dari penyimpanan HP
- Shuffle, repeat (off / semua / satu lagu), dan sleep timer
- Mini-player persisten yang selalu terlihat di semua halaman

### 🏷️ Metadata Otomatis
- Auto-fetch judul, artis, album art, dan genre lagu via iTunes Search API
- Auto-fetch lirik via lyrics.ovh
- Edit metadata manual (judul, artis, album, genre, region, lirik) untuk lagu yang tidak ditemukan otomatis
- Scan ulang metadata per-lagu atau sekaligus semua lagu (bulk scan)

### 📁 Organisasi
- Browse lagu berdasarkan folder asal file
- Sembunyikan folder tertentu dari library
- Playlist kustom, favorit, dan riwayat baru diputar
- Pencarian real-time (judul, artis, album)
- Urutkan berdasarkan judul (A-Z/Z-A), artis, tanggal ditambahkan, atau genre

### 📊 Dashboard Analitik
- Grafik jam mendengarkan musik 7 hari terakhir
- Lagu dan artis yang paling sering didengarkan
- Distribusi genre dan asal region lagu dalam koleksi

---

## 🛠️ Tech Stack

| Kategori | Package |
|---|---|
| Audio playback | `just_audio`, `audio_service` |
| Scan file lokal | `on_audio_query` |
| Database lokal | `sqflite` |
| State management | `provider` |
| Grafik dashboard | `fl_chart` |
| Metadata & lirik | iTunes Search API, lyrics.ovh |

---

## 🚀 Menjalankan Project

```bash
git clone https://github.com/nekonaru/musicapp.git
cd musicapp
flutter pub get
flutter run
```

Build APK release otomatis tersedia lewat GitHub Actions - cek tab **Actions** untuk mengunduh hasil build terbaru.

### Permission Android yang dibutuhkan
Aplikasi ini memerlukan izin akses musik (`READ_MEDIA_AUDIO`), internet (untuk fetch metadata & lirik), dan foreground service (untuk pemutaran latar belakang). Semua sudah dikonfigurasi otomatis di `AndroidManifest.xml`.

---

## 📱 Struktur Project

```
lib/
├── models/          # Model data (Song, ListeningEntry)
├── services/        # Logic inti (database, player, scanner, metadata)
├── providers/        # State management
├── screens/          # Semua tampilan UI
└── widgets/          # Komponen UI reusable (mini-player, dll)
```

---

## 📄 Lisensi

Project ini dilisensikan di bawah [MIT License](LICENSE) - bebas digunakan, dimodifikasi, dan didistribusikan ulang dengan tetap mencantumkan atribusi.

---

<div align="center">
Dibuat oleh <b>Nicolas Dwi Dharma</b>
</div>
