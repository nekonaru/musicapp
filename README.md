<div align="center">

# 🎵 Swara - Pemutar Musik Offline

**Putar koleksi musik HP tanpa internet, dengan metadata dan lirik otomatis, plus dashboard analitik kebiasaan mendengarkanmu.**

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?style=flat-square&logo=flutter&logoColor=white)
![Release](https://img.shields.io/github/v/release/nekonaru/musicapp?style=flat-square&color=blue)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)
![CI](https://github.com/nekonaru/musicapp/actions/workflows/build-apk.yml/badge.svg)

</div>

## 📖 Tentang

**Swara** adalah aplikasi pemutar musik offline berbasis Flutter. Scan dan putar lagu langsung dari penyimpanan HP - tanpa akun, tanpa iklan, tanpa internet. Judul, artis, cover album, genre, dan lirik dilengkapi otomatis dari internet, dan semua aktivitas mendengarkan dirangkum di dashboard analitik.

> _"Koleksi musikmu, didengarkan dengan tenang, bahkan tanpa internet."_

## ✨ Fitur

| Fitur | Deskripsi |
|-------|-----------|
| ▶️ **Putar offline** | Scan dan putar musik langsung dari penyimpanan HP |
| 🔔 **Background playback** | Musik tetap jalan + kontrol dari notifikasi dan lockscreen (MediaSession) |
| 🔀 **Shuffle & repeat** | Acak, ulangi mati / semua / satu lagu, plus sleep timer waktu atau jumlah lagu |
| ⏱️ **Mini player** | Selalu terlihat di semua halaman; kontrol kecepatan 0.5x–2x |
| 📝 **Antrean putar** | Tambah lagu untuk diputar berikutnya / di akhir antrean, reorder & hapus |
| 🌐 **Metadata otomatis** | Judul, artis, cover album, dan genre via iTunes Search API |
| 🎤 **Lirik otomatis** | Fetch via lyrics.ovh, bisa edit manual atau cari di Google |
| ✏️ **Edit manual** | Koreksi metadata dan lirik per lagu bila hasil otomatis kurang pas |
| 📁 **Browse folder** | Lihat lagu per folder asal, sembunyikan folder tertentu dari library |
| 🔤 **Navigasi A–Z** | Geser scrollbar huruf di sisi kanan untuk lompat cepat |
| 💿 **Playlist & favorit** | Playlist kustom, favorit, dan riwayat baru diputar |
| 🔍 **Pencarian** | Real-time berdasarkan judul, artis, album, folder, atau genre |
| 📊 **Dashboard** | Grafik 7 hari terakhir, top lagu & artis, distribusi genre & region |
| 🎨 **Tema** | Terang, gelap, atau ikuti sistem + 10 warna aksen |

## 📱 Instalasi

### Opsi A: Download APK (termudah)

1. Buka halaman [Releases](https://github.com/nekonaru/musicapp/releases)
2. Download `app-release.apk` dari versi terbaru
3. Buka file-nya di HP, izinkan instalasi dari sumber tidak dikenal bila diminta
4. Izinkan akses audio saat aplikasi pertama kali dibuka

> Minimum Android: 8.0 (API 26).

### Opsi B: Build dari source (untuk development)

**1. Prasyarat**

- [Flutter](https://flutter.dev) 3.47+ (stable)
- JDK 17
- Android SDK (API 34+)

**2. Ambil kode dan build**

```bash
git clone https://github.com/nekonaru/musicapp.git
cd musicapp
flutter pub get
flutter analyze
flutter build apk --release
```

Hasilnya ada di `build/app/outputs/flutter-apk/app-release.apk`.

> Belum pernah pakai terminal? Ketik perintah di atas satu per satu di PowerShell/Terminal lalu tekan **Enter** setiap baris.

## 🛠️ Tech Stack

| Kategori | Package / Layanan |
|---|---|
| Audio playback | just_audio |
| Notifikasi & lockscreen | audio_service (MediaSession) |
| Scan file lokal | on_audio_query |
| Database lokal | sqflite |
| State management | provider |
| Grafik dashboard | fl_chart |
| Metadata & lirik | iTunes Search API, lyrics.ovh |
| CI (build APK + rilis) | GitHub Actions |

## 📝 Catatan rilis

Setiap versi punya catatan perubahan bilingual (Inggris–Indonesia) di halaman [Releases](https://github.com/nekonaru/musicapp/releases) dengan format: ✨ fitur baru, ⚡ pengoptimalan, 🐛 perbaikan bug, 📦 instalasi.

## 📄 Lisensi

Source code open source di bawah lisensi MIT - bebas dipakai, dimodifikasi, dan didistribusikan ulang termasuk komersial, selama notice lisensi disertakan. Lihat [LICENSE](LICENSE).

APK di halaman Releases bebas digunakan untuk keperluan pribadi.

---

<div align="center">

Dibuat oleh Nicolas Dwi Dharma

</div>
