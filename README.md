# 🎣 Advanced Auto Fishing Hub (Roblox Lua / Luau)

Script Lua auto-fishing modern dan modular untuk Roblox (kompatibel dengan game seperti **Fisch**, **Fishing Simulator**, dan game mancing lainnya).

File utama: [main.lua](file:///c:/Users/Dipo/projects/rblox%20script/fishon%20meto/main.lua)

---

## ✨ Fitur-Fitur Utama

### 1. 🧭 Navigation Bar (Tabs)
* **Auto Fishing**: Pengaturan utama untuk melempar umpan, shake button, dan reel minigame.
* **Sell**: Kontrol Auto Sell ikan dan tombol manual "Sell All Fish Now".
* **Settings & Misc**: Teleport Safe Zone (floating platform) & Anti-AFK.

### 2. 🎚️ Sliders & Kecepatan (Speed Control)
* **Cast Delay**: Mengatur jeda waktu antar lemparan umpan (0.2s - 5.0s).
* **Shake / Reel Speed**: Kecepatan klik tombol shake atau reel minigame (0.02s - 0.5s).
* **Cast Power**: Mengatur persentase kekuatan lemparan (20% - 100%).
* **Auto Sell Interval**: Waktu berkala untuk menjual semua ikan (5s - 60s).

### 3. 🎯 Logika Mancing Otomatis
* **Auto Cast**: Otomatis mendeteksi pancingan (Rod) di karakter/backpack dan mengeksekusi cast (mendukung remote game seperti Fisch maupun `Tool:Activate()`).
* **Auto Shake**: Otomatis mendeteksi dan mengeklik tombol Shake UI (seperti lingkaran klik di Fisch).
* **Auto Reel / Instant Catch**: Mengikuti pergerakan bar ikan atau langsung menyelesaikan minigame (`reelfinished`).
* **Auto Sell**: Menjual ikan melalui RemoteEvent/RemoteFunction game atau interaksi dengan Merchant ProximityPrompt.
* **Anti-AFK Built-in**: Mencegah disconnect idle 20 menit dari Roblox.

---

## ⚡ Quick Loadstring (Dengan Proteksi `pcall`)

Salin baris kode di bawah ini ke executor kamu:

```lua
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/feath1v1/fishon/refs/heads/main/main.lua"))()
end)
```

Atau jika ingin melihat status output error jika gagal memuat:

```lua
local success, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/feath1v1/fishon/refs/heads/main/main.lua"))()
end)
if not success then
    warn("[FISHING HUB ERROR]:", err)
end
```

---

## 🚀 Cara Menjalankan Manual

1. Salin seluruh isi dari file [main.lua](file:///c:/Users/Dipo/projects/rblox%20script/fishon%20meto/main.lua).
2. Buka executor Roblox pilihan kamu (Delta, Arceus X, Codex, Solara, Wave, dll.).
3. Tempel (*paste*) script ke executor lalu klik **Execute**.
4. Menu UI modern akan muncul di tengah layar:
   - Geser (*drag*) topbar untuk memindahkan posisi menu.
   - Pilih tab di sebelah kiri (Auto Fishing, Sell, Settings).
   - Aktifkan toggle dan sesuaikan slider kecepatan sesuai kebutuhan.
