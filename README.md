# ValzzHost — Ubuntu 24.04 SSH (Persistent Edition)

Lingkungan Ubuntu 24.04 untuk Railway atau Docker, dilengkapi OpenSSH, Node.js 26 LTS, npm, PM2, dan tool developer. Versi ini difokuskan pada stabilitas proses jangka panjang, keamanan login, dan penyimpanan persisten.

> **Penting:** ini tetap container, bukan VPS dengan systemd penuh. Untuk menyimpan file dan proses lintas redeploy, pasang Railway Volume ke `/data`. Tanpa volume, isi `/data` tetap dapat hilang saat container dibuat ulang.

## Yang ditingkatkan

- Ubuntu 24.04 LTS dan Node.js 26 LTS; Node 26 berada pada jalur Active LTS dan dijadwalkan menerima update sampai April 2029.
- OpenSSH memakai konfigurasi eksplisit, validasi `sshd -t`, batas percobaan autentikasi, dan keepalive.
- Dukungan login password tetap tersedia agar deployment lama tidak langsung berubah. Login berbasis SSH key juga didukung.
- User tambahan tidak lagi mendapat `sudo NOPASSWD` secara default.
- Tersedia `SSH_PASSWORD_AUTH`, `SSH_ROOT_LOGIN`, dan `SSH_SUDO_NOPASSWD` untuk mengatur tingkat keamanan.
- `/workspace`, `/root/projects`, PM2 state, package global npm, dan SSH host keys diarahkan ke `/data`.
- Jika `pm2 save` pernah dijalankan, proses yang tersimpan akan dicoba dipulihkan saat container mulai.
- Tersedia `server-status` untuk memeriksa RAM/cgroup, CPU quota, disk, SSH, Node, npm, dan PM2; `backup-data` untuk membuat arsip backup.
- Tini membantu meneruskan sinyal shutdown dan menangani proses anak.
- Healthcheck TCP untuk penggunaan Docker lokal.

## Deploy ke Railway

### 1. Deploy project

Push seluruh isi project versi 2.0.2 ini ke repository GitHub milikmu, lalu hubungkan repository tersebut ke Railway dan deploy menggunakan `Dockerfile`.

> **Penting:** Railway Template Composer saat ini dikonfigurasi melalui dashboard. File `railway-template.json` dan `.env.example` di repository adalah referensi/daftar variable; Railway tidak otomatis menjadikannya form input deployment hanya karena file itu ada. Ikuti langkah di bagian **Membuat form input saat Deploy Template** di bawah.

### 2. Isi Variables

Isi `ROOT_PASSWORD` dengan password acak yang kuat. Isi `VALZZ_HOSTNAME` dengan nama server yang ingin ditampilkan, misalnya `valzzhost`.

#### Membuat form input saat Deploy Template

**Penting:** file `railway-template.json` dan `.env.example` di GitHub tidak otomatis menjadi form input pada Railway Template Composer. Supaya pengguna diminta mengisi data saat menekan **Deploy**, konfigurasi variable pada dashboard Railway:

1. Buka Template Composer dan pilih service ValzzHost yang terhubung ke repository ini.
2. Buka tab **Variables**.
3. Pilih **Raw Editor**, lalu tempel konfigurasi awal berikut:

```env
ROOT_PASSWORD=
VALZZ_HOSTNAME=valzzhost
SSH_PASSWORD_AUTH=true
SSH_ROOT_LOGIN=yes
SSH_USERNAME=
SSH_PASSWORD=
AUTHORIZED_KEYS=
SSH_USER_AUTHORIZED_KEYS=
SSH_SUDO_NOPASSWD=false
NODE_OPTIONS=
```

4. Simpan/update variable, lalu buka pengaturan setiap variable dan atur Required, Secret, serta deskripsinya sesuai tabel berikut.

| Variable | Required saat deploy | Secret | Keterangan |
|---|---:|---:|---|
| `ROOT_PASSWORD` | Ya | Ya | Password untuk login SSH sebagai root. Wajib diisi dengan password unik yang kuat. |
| `VALZZ_HOSTNAME` | Ya | Tidak | Hostname Linux kustom, misalnya `valzzhost`. Hanya huruf, angka, titik, dan tanda hubung. |
| `SSH_PASSWORD_AUTH` | Tidak | Tidak | Izinkan login SSH memakai password; default `true`. |
| `SSH_ROOT_LOGIN` | Tidak | Tidak | Mode login root: `yes`, `no`, atau `prohibit-password`; default `yes`. |
| `SSH_USERNAME` | Tidak | Tidak | Username SSH tambahan. Jika diisi, `SSH_PASSWORD` juga wajib diisi. |
| `SSH_PASSWORD` | Tidak | Ya | Password untuk user SSH tambahan. |
| `AUTHORIZED_KEYS` | Tidak | Ya | Public key SSH untuk root. Bisa berisi beberapa baris public key. |
| `SSH_USER_AUTHORIZED_KEYS` | Tidak | Ya | Public key SSH untuk user tambahan. |
| `SSH_SUDO_NOPASSWD` | Tidak | Tidak | Beri sudo tanpa password untuk user tambahan; default `false`. |
| `NODE_OPTIONS` | Tidak | Tidak | Opsi runtime Node.js; sesuaikan dengan batas RAM container. |

Aktifkan **Required** untuk `ROOT_PASSWORD` dan `VALZZ_HOSTNAME`. Tandai `ROOT_PASSWORD`, `SSH_PASSWORD`, `AUTHORIZED_KEYS`, dan `SSH_USER_AUTHORIZED_KEYS` sebagai **Secret**. Tambahkan deskripsi variable agar pengguna tahu fungsinya. Simpan template, lalu uji preview/deploy untuk memastikan dua input wajib itu muncul.

`.env.example` membantu Railway mendeteksi/menyarankan nama variable saat menghubungkan repository, tetapi status **Required**, **Secret**, dan deskripsi tetap harus diperiksa di Template Composer. Lihat juga [RAILWAY-TEMPLATE-SETUP.md](RAILWAY-TEMPLATE-SETUP.md).

**Catatan akun tambahan:** `SSH_USERNAME` dan `SSH_PASSWORD` harus diisi bersamaan atau dibiarkan kosong keduanya. Jika hanya salah satu diisi, container akan berhenti dengan pesan error yang jelas.

### 3. Pasang persistent volume (sangat disarankan)

Di Railway, buka service → **Volumes** → buat/attach volume → set **Mount Path** menjadi:

```text
/data
```

Volume Railway tersedia di path mount saat container dijalankan. File pada `/workspace`, `/root/projects`, `/root/.pm2`, package global npm, dan `/data/ssh` akan disimpan di volume ini.

Railway membatasi satu volume per service dan service dengan volume tidak dapat memakai replicas. Volume Railway tidak otomatis menjadi backup eksternal. Jalankan `backup-data` secara berkala dan salin arsipnya ke perangkat atau penyimpanan lain. Pada paket berbayar, perbesar kapasitas volume melalui pengaturan volume jika storage mulai penuh. Ketika service menggunakan volume, redeploy dapat menyebabkan sedikit downtime karena Railway memastikan volume tidak dipakai dua deployment aktif sekaligus.

### 4. Aktifkan TCP Proxy

Atur restart policy ke **On Failure** (kompatibel dengan plan Free/Trial). Pada plan berbayar, Railway juga menyediakan **Always** untuk restart setiap kali service berhenti. Untuk shutdown lebih rapi ketika redeploy, atur variable opsional `RAILWAY_DEPLOYMENT_DRAINING_SECONDS=30`.

Buka Settings → Networking → buat **TCP Proxy** ke port container:

```text
22
```

Lalu hubungkan dari terminal:

```bash
ssh root@HOST_RAILWAY -p PORT
```

Atau gunakan akun tambahan:

```bash
ssh USERNAME@HOST_RAILWAY -p PORT
```

## Pengaturan keamanan yang disarankan

Untuk server yang bisa diakses internet, lebih baik gunakan SSH key:

1. Masukkan public key ke `AUTHORIZED_KEYS` (root) atau `SSH_USER_AUTHORIZED_KEYS` (user tambahan).
2. Pastikan key bisa login setelah redeploy.
3. Set `SSH_PASSWORD_AUTH=false`.
4. Set `SSH_ROOT_LOGIN=prohibit-password` untuk root key-only, atau `SSH_ROOT_LOGIN=no` dan login memakai user tambahan.

Jangan menonaktifkan password sebelum public key berhasil diuji. Entrypoint memeriksa beberapa konfigurasi yang berisiko membuat tidak ada jalur login, tetapi tetap pastikan key yang digunakan benar.

## RAM, CPU, dan storage

**RAM tidak bisa ditambah oleh Dockerfile atau script.** Batas aktual ditentukan resource service dan plan Railway. Naikkan Memory dan CPU limit dari pengaturan resource service sesuai paket yang digunakan. Cek penggunaan aktual melalui tab **Metrics** atau jalankan:

```bash
server-status
```

Jangan menaikkan batas heap Node secara membabi buta. `NODE_OPTIONS=--max-old-space-size=4096` berarti satu proses Node dapat menggunakan heap hingga sekitar 4 GB, belum termasuk native memory, PM2, SSH, dan proses lain. Sisakan ruang untuk sistem operasi dan aplikasi lain. Jika menjalankan banyak aplikasi Node melalui PM2, konfigurasi heap masing-masing aplikasi lebih aman daripada satu `NODE_OPTIONS` global.

Menurut dokumentasi Railway saat ini, batas resource per replica bergantung pada plan: Free sekitar 0.5 GB RAM/1 vCPU, Hobby hingga 8 GB/8 vCPU, dan Pro hingga 24 GB/24 vCPU. Batas akun, konfigurasi service, dan jumlah replica tetap berlaku. Periksa halaman resource Railway sebelum menentukan ukuran.

Contoh untuk satu aplikasi Node dengan RAM container 4 GB:

```text
NODE_OPTIONS=--max-old-space-size=2560
```

Angka tersebut hanya contoh awal, bukan rekomendasi universal. Pantau RAM aktual sebelum menaikkannya.

## Penyimpanan dan proses yang bertahan

Lokasi kerja yang direkomendasikan:

```text
/workspace       -> /data/workspace
/root/projects   -> /data/projects
/root/.pm2       -> /data/.pm2
/data/.npm-global
/data/ssh        (private host keys; jangan dibagikan)
```

Contoh menjalankan bot Node.js:

```bash
cd /workspace
npm init -y
# buat app.js
pm2 start app.js --name bot-utama
pm2 save
pm2 list
```

Untuk PM2 yang dijalankan dari akun root, daftar proses yang tersimpan dengan `pm2 save` akan dicoba dipulihkan otomatis saat container mulai lagi. PM2 milik user tambahan memiliki home persisten, tetapi perlu dijalankan dengan `pm2 resurrect` secara manual setelah login. Jika aplikasi gagal dipulihkan, SSH tetap akan dinyalakan agar masalah bisa diperiksa:

```bash
pm2 list
pm2 logs bot-utama --lines 100
pm2 restart bot-utama
pm2 save
```

Package global npm yang dipasang root setelah container berjalan disimpan ke `/data/.npm-global`. Password yang diganti langsung dengan `passwd` di dalam container akan ditimpa lagi oleh `ROOT_PASSWORD` saat restart; ubah nilainya dari Railway Variables agar tetap berlaku. Untuk user tambahan, prefix global disimpan di home user yang persisten:

```bash
npm install -g nama-package
```

Package yang sudah terpasang di image (contohnya PM2) tetap ada di image. Data user yang disimpan di luar path persisten dapat hilang ketika redeploy.

## Backup manual

Buat arsip data penting dengan satu perintah:

```bash
backup-data
```

Arsip dibuat di `/data/backups`. Untuk menentukan lokasi atau nama file sendiri:

```bash
backup-data /data/backups/backup-manual.tar.gz
```

Salin arsip ke perangkat sendiri dari terminal lokal:

```bash
scp -P PORT root@HOST_RAILWAY:/data/backups/NAMA_FILE.tar.gz .
```

Arsip yang hanya disimpan di volume yang sama belum melindungi dari kehilangan volume. Simpan salinan di tempat berbeda. Folder `ssh` berisi private host key; simpan arsip itu secara rahasia. User tambahan mendapatkan home directory persisten di `/data/users/<username>`. Folder `/workspace` memakai grup `workspace` agar root dan user tambahan dapat bekerja pada project yang sama.

## Perintah berguna

| Perintah | Fungsi |
|---|---|
| `server-status` | Status RAM, CPU, disk, SSH, Node, npm, PM2. |
| `backup-data` | Arsip workspace, project, PM2, package global, home user, dan SSH host keys. |
| `pm2 list` | Daftar proses PM2. |
| `pm2 logs` | Log aplikasi. |
| `pm2 save` | Simpan daftar proses untuk pemulihan. |
| `htop` | Pantau proses dan resource. |
| `tmux` | Sesi terminal persisten selama container hidup. |
| `neofetch` | Informasi sistem (dipasang bila tersedia di repository Ubuntu). |

## Menjalankan secara lokal dengan Docker Compose

Salin `.env.example` menjadi `.env`, ubah password, lalu jalankan:

```bash
docker compose up -d --build
```

Koneksi lokal:

```bash
ssh root@127.0.0.1 -p 2222
```

Volume Docker bernama `ssh-data` akan menyimpan `/data`.

## Catatan operasional

- Tidak ada script yang dapat menjamin server hidup selamanya. Railway dapat melakukan restart, redeploy, maintenance, atau menghentikan service sesuai batas platform dan penggunaan resource.
- Untuk layanan kritikal, gunakan backup di luar volume, pantau Metrics, simpan log aplikasi, dan uji pemulihan backup. Rebuild/redeploy secara berkala agar image menerima security update OS dan runtime terbaru.
- Jangan menjalankan database produksi hanya di filesystem ephemeral. Gunakan volume atau database terkelola dengan backup.
- Node.js 26 adalah LTS saat versi project ini dibuat; tetap jadwalkan upgrade runtime sebelum masa dukungannya berakhir.

## Referensi resmi

- [Node.js release schedule](https://nodejs.org/en/about/previous-releases)
- [Railway Volumes](https://docs.railway.com/volumes)
- [Railway resource metrics](https://docs.railway.com/observability/metrics)
- [Railway scaling](https://docs.railway.com/deployments/scaling)
- [Railway restart policy](https://docs.railway.com/deployments/restart-policy)

---

© ValzzHost · MIT License
