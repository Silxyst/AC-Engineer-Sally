# AC Engineer Sally

Assetto Corsa Custom Shaders Patch (CSP) Lua app that provides an automatic
race engineer and proximity spotter using prerecorded Sally voice clips. It
does not use TTS, speech recognition, network services, or external processes.

The written interface supports Portuguese (Brazil) and English. Sally's
recorded voice remains English.

## Requirements

- Assetto Corsa with CSP Lua Apps support enabled.
- A Sally-compatible voice pack installed locally in `audio/sally/`.
- Permission to use the selected voice pack.

## Installation

1. Copy this directory to `assettocorsa/apps/lua/AC-Engineer-Sally/`.
2. Install a compatible voice pack under `audio/sally/<category>/<phrase>/`.
3. Start Assetto Corsa, enable the app in CSP Lua Apps, and open Settings.
4. Select `Português` or `English` in the app settings if needed.

`config.ini` contains repository defaults. The app creates and updates
`user_settings.ini` locally; that file is deliberately not versioned.

## Content Notice

The optional Rants setting can play explicit or abrasive voice clips. It is
disabled by default. Enable it only if appropriate for everyone who can hear
the game audio.

## Audio Assets and Licensing

The code is licensed under Apache-2.0. Third-party asset attribution is in
`NOTICE`. Redistribute the bundled voice assets only under their applicable
terms.

## Development Checks

- Parse every Lua module after editing.
- Confirm every literal `api.say(category, phrase, ...)` has at least one WAV
  in the installed local pack.
- Test in an actual CSP session: audio queue, spotter interruptions, race
  flags, pit entry/exit, telemetry availability, and language switching.
