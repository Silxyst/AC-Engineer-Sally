<a id="top"></a>
<div align="center">

<img src="../assets/sally-hero.svg?v=2" alt="AC Engineer Sally — your team on the radio" width="100%">
<p><img src="../icon.png" width="112" alt="Sally wearing a headset"></p>

<h1>🎙️ AC Engineer Sally</h1>
<p><strong>You drive. Sally keeps up.</strong><br>
Automatic race engineer and proximity spotter for <strong>Assetto Corsa + CSP</strong>.<br>
Prerecorded voice, live telemetry, and a dedicated race hub.</p>

<p>
<img src="https://img.shields.io/badge/version-1.0.0-FFD43B?style=flat-square" alt="Version 1.0.0">
<img src="https://img.shields.io/badge/Assetto_Corsa-CSP-DC2626?style=flat-square&amp;logo=steam&amp;logoColor=white" alt="Assetto Corsa with CSP">
<img src="https://img.shields.io/badge/interface-PT--BR_%7C_EN-22C55E?style=flat-square" alt="Portuguese and English interface">
<a href="../LICENSE"><img src="https://img.shields.io/github/license/Silxyst/AC-Engineer-Sally?style=flat-square&amp;color=FFD43B" alt="Code license"></a>
</p>
<p><a href="#features">✨ Features</a> · <a href="#install">📥 Install</a> · <a href="#settings">🎛️ Settings</a> · <a href="#help">❓ Help</a></p>
<p><a href="../README.md">🇧🇷 Português</a> · 🇬🇧 <strong>English</strong></p>

</div>

<a id="features"></a>
## ✨ Your team on the radio

| System | What it does |
|:---|:---|
| **Proximity spotter** | Left/right traffic, overlap, three-wide calls and clear-track calls, with priority over engineer reports. |
| **Fuel and strategy** | Learns fuel consumption per lap and estimates range, reserve and fuel required to finish. |
| **Car condition** | Tyre temperatures, pressures, wear, damage and engine data when supplied by the car and CSP. |
| **Race awareness** | Flags, positions, gaps, pit entry/exit, session clock and simulator-reported penalties. |
| **Race hub** | Fuel, range, remaining laps, last/best lap, tyres, spotter status and radio history. |
| **Local audio** | English Sally voice clips, PT-BR/English interface and captions, independent volumes and playback settings. |
| **Telemetry commentary** | Local rules select existing Sally recordings after valid laps in practice, qualifying or race, using pace and position; no internet or API key is needed. |
| **2D Sally avatar** | Transparent character art with idle and speaking images; up to 14 expressions are mapped to audio types and can be previewed or hidden in Settings. |
| **Race-finish reaction** | At the end of a race, Sally selects a recorded call for the final position, including a win, podium, good finish or last place. Result calls have captions. |

The pack includes **25 categories and 6,222 Sally WAVs**, stored with Git LFS. Radio playback uses priorities, cooldowns and message expiry. Weather, DRS, ERS and push-to-pass calls depend on available telemetry.

> 🧪 **In-game check:** image/audio mappings have been checked. Expression changes on screen and race-finish triggers still need confirmation in an Assetto Corsa/CSP session.

<a id="install"></a>
## 📥 Installation

**Requirements:** Assetto Corsa on Windows, CSP with Lua Apps enabled, and Git + Git LFS to download the bundled audio.

### 1. Download the complete app

```powershell
git lfs install
git clone https://github.com/Silxyst/AC-Engineer-Sally.git
git -C "AC-Engineer-Sally" lfs pull
```

Source-code ZIPs may contain LFS pointers instead of playable WAV files. The commands above retrieve the actual audio.

### 2. Install with the game closed

Copy the `AC-Engineer-Sally` directory into:

```text
assettocorsa/apps/lua/AC-Engineer-Sally/
```

Keep the directory name **`AC-Engineer-Sally`** and entry filename **`AC-Engineer-Sally.lua`**.

### 3. Enable and test

1. In Content Manager, check that **CSP → Lua Apps** is enabled and enable **AC Engineer Sally** in the apps list.
2. Enter a session and open the main window from the apps sidebar.
3. Open its **Settings**, select **English** or **Português**, and run **Radio check**.
4. Adjust engineer/spotter volumes and open the **Central de Corrida** race hub.
5. Drive: race calls are automatic.

<a id="settings"></a>
## 🎛️ Make the radio yours

- Separate engineer and spotter volumes, radio background and beep.
- Playback speed and pitch.
- Toggles for flags, fuel, tyres, damage and summaries.
- Summary frequency, fuel-status interval and fuel reserve in laps.
- Radio check, spotter tests, call sequence, queue clearing and phrase catalog.
- Optional Rants level `0–3`; distributed defaults use `0` (off). Some clips in the pack contain explicit language.
- Local telemetry commentary: selects existing recordings after valid laps based on pace and position. No online AI, API key or internet connection is used.
- Sally's 2D avatar can be shown or hidden, and its expressions can be previewed in Settings.

`config.ini` supplies defaults. Changes made in the app are saved locally to `user_settings.ini`, which overrides defaults and is excluded from Git.

<a id="help"></a>
## ❓ Quick answers

<details>
<summary><strong>Sally is silent</strong></summary>
<br>
Run <strong>Radio check</strong> in Settings. Check both volumes, the radio toggle in the hub, and the <code>audio/sally/</code> directory. If your download contains LFS pointers, run <code>git lfs pull</code> in the clone and copy the complete audio into the installed app.
</details>

<details>
<summary><strong>Does the voice switch to Portuguese?</strong></summary>
<br>
Sally's prerecorded voice is <strong>English</strong>. The language selector changes the interface and captions.
</details>

<details>
<summary><strong>Does it require internet while driving?</strong></summary>
<br>
The radio, alerts and telemetry commentary run locally and work without an internet connection or API key.
</details>

<details>
<summary><strong>Why are some calls unavailable on my car?</strong></summary>
<br>
Calls depend on the features and telemetry exposed by the car, mod and CSP. DRS, ERS, wear, engine, weather and penalty calls require the corresponding data. Penalties use native Assetto Corsa/CSP data; the Real Penalty mod is not integrated. Fuel estimates improve as you complete laps.
</details>

<details>
<summary><strong>How do I update and keep my preferences?</strong></summary>
<br>
Run <code>git pull</code> and <code>git lfs pull</code> in the clone, close the game and copy the updated files into the installation. Preserve your local <code>user_settings.ini</code>.
</details>

## 🤝 Feedback and contributions

[Open an Issue](https://github.com/Silxyst/AC-Engineer-Sally/issues/new) with your CSP version, car/mod, track, session type, expected behavior and actual result. Screenshots and relevant logs help reproduce the issue.

For Lua changes, validate syntax and audio references, then check spotter calls, radio interruptions, language switching, flags and pit exit in a CSP session.

## 📜 Credits and license

- **Indie project:** [Silxyst](https://github.com/Silxyst) · AC Engineer Sally.
- **Code:** [Apache License 2.0](../LICENSE).
- **Sally voice:** pack created with [crew-chief-autovoicepack](https://github.com/cktlco/crew-chief-autovoicepack); asset attribution and terms in [NOTICE](../NOTICE).
- **Platform:** Assetto Corsa and Custom Shaders Patch.

<div align="center">
<img src="../assets/sally-divider.svg" alt="" width="100%">
<p><strong>Enjoy having Sally on the radio? Leave a ⭐!</strong></p>
<sub>Built for the Assetto Corsa community · <a href="#top">back to top ↑</a></sub>
</div>
