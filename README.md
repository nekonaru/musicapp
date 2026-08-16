<div align="center">

# 🎵 Swara

Aplikasi pemutar musik offline berbasis Flutter, dengan metadata otomatis, lirik, dan dashboard analitik pendengaran.

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://github.com/nekonaru/musicapp)

</div>

---

## Fitur

### Pemutaran
- Scan dan putar musik offline langsung dari penyimpanan HP
- Musik tetap berjalan di latar belakang, tidak berhenti saat tombol kembali ditekan
- Shuffle, repeat (mati, semua, satu lagu), dan sleep timer dengan durasi kustom
- Mini player persisten yang selalu terlihat di semua halaman
- Kontrol kecepatan putar, dari 0.5x sampai 2x
- Swipe ke bawah untuk minimize, swipe kiri atau kanan untuk ganti lagu
- Antrean putar, bisa menambah lagu untuk diputar berikutnya atau di akhir antrean

### Metadata Otomatis
- Auto fetch judul, artis, album art, dan genre lagu lewat iTunes Search API
- Auto fetch lirik lewat lyrics.ovh, dengan opsi cari manual di Google
- Edit metadata manual untuk lagu yang tidak ditemukan otomatis
- Scan ulang metadata per lagu, atau sekaligus semua lagu

### Organisasi
- Browse lagu berdasarkan folder asal file
- Sembunyikan folder tertentu, lagunya otomatis tidak muncul di daftar utama
- Navigasi cepat A sampai Z dengan menggeser jari di sisi kanan layar
- Playlist kustom, favorit, dan riwayat baru diputar
- Pencarian real time berdasarkan judul, artis, atau album
- Urutkan berdasarkan judul, artis, tanggal ditambahkan, atau genre
- Menu lengkap per lagu: putar berikutnya, tambah ke playlist, ganti nama, edit metadata, hapus

### Dashboard Analitik
- Grafik jam mendengarkan musik untuk 7 hari terakhir
- Lagu dan artis yang paling sering didengarkan
- Distribusi genre dan asal region lagu dalam koleksi

### Tampilan
- Tema terang, gelap, atau ikuti sistem
- Animasi halus di berbagai transisi dan interaksi
- Konfirmasi "tekan sekali lagi untuk keluar" saat menutup aplikasi

---

## Download

Aplikasi bisa langsung diunduh dari halaman [Releases](https://github.com/nekonaru/musicapp/releases) tanpa perlu membangun dari source code.

---

## Tech Stack

| Kategori | Package |
|---|---|
| Audio playback | just_audio, just_audio_background |
| Scan file lokal | on_audio_query |
| Database lokal | sqflite |
| State management | provider |
| Grafik dashboard | fl_chart |
| Metadata dan lirik | iTunes Search API, lyrics.ovh |

---

## Lisensi

Source code project ini bersifat proprietary. Boleh dilihat untuk keperluan portofolio, namun tidak boleh disalin, dimodifikasi, atau didistribusikan ulang tanpa izin tertulis dari pemilik hak cipta. Lihat file [LICENSE](LICENSE) untuk detail lengkap.

Aplikasi (APK) yang tersedia di halaman Releases bebas digunakan untuk keperluan pribadi.

---

<div align="center">
Dibuat oleh Nicolas Dwi Dharma
</div>
