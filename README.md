<div align="center">

# 🎵 Swara

**Aplikasi pemutar musik offline berbasis Flutter dengan metadata otomatis, lirik, dan dashboard analitik pendengaran.**

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://github.com/nekonaru/musicapp)

</div>

---

## ✨ Fitur

### 🎧 Pemutaran
- Scan & putar musik offline langsung dari penyimpanan HP
- Shuffle, repeat (off / semua / satu lagu), dan sleep timer dengan durasi kustom
- Mini-player persisten yang selalu terlihat di semua halaman
- Kontrol kecepatan putar (0.5x sampai 2x)
- Swipe ke bawah untuk minimize, swipe kiri/kanan untuk ganti lagu

### 🏷️ Metadata Otomatis
- Auto-fetch judul, artis, album art, dan genre lagu via iTunes Search API
- Auto-fetch lirik via lyrics.ovh, dengan opsi cari manual di Google
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

### 🎨 Tampilan
- Tema terang, gelap, atau ikuti sistem
- Animasi halus di berbagai transisi dan interaksi

---

## 📥 Download

Aplikasi bisa langsung diunduh dari halaman [**Releases**](https://github.com/nekonaru/musicapp/releases) tanpa perlu membangun dari source code.

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

## 📄 Lisensi

Source code project ini bersifat **proprietary** — dapat dilihat untuk keperluan portofolio, namun **tidak boleh disalin, dimodifikasi, atau didistribusikan ulang** tanpa izin tertulis dari pemilik hak cipta. Lihat file [LICENSE](LICENSE) untuk detail lengkap.

Aplikasi (APK) yang tersedia di halaman Releases bebas digunakan untuk keperluan pribadi.

---

<div align="center">
Dibuat oleh <b>Nicolas Dwi Dharma</b>
</div>
