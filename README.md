# SoundPaper

A live, audio-reactive desktop wallpaper for macOS. It listens to whatever's playing in Spotify or Apple Music and turns your desktop into a puddle, an ocean, a nebula, or a swirling black hole that moves with the bass, melody, vocals, and beat.

**[Download for macOS](https://sidraghu07.github.io/SoundPaper/)**

## Features

- **Five atmospheres**: Waveform, Puddle, Space, Ocean, Black Hole — each reacts differently to bass, melody, and vocals.
- **Album art colors**: the whole scene is tinted from the currently playing track's artwork.
- **Audio source toggle**: pick whether SoundPaper listens to Spotify or Apple Music.
- **Now Playing widget**: an optional on-desktop widget showing the current track.
- **Visual effects**: kaleidoscope, echo trails, chromatic aberration, and hue cycling, with presets or a custom combination.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel
- Spotify or Apple Music (for audio + Now Playing metadata)

## Installation

1. Open the downloaded `SoundPaper.dmg`.
2. Drag **SoundPaper** into the **Applications** shortcut in the same window.
3. Open it from Applications — see [Gatekeeper](#macos-blocks-it-the-first-time) below, since this isn't a notarized App Store app.
4. When prompted, grant **Screen Recording** permission in System Settings → Privacy & Security (this is how it listens to your music), then relaunch.
5. Use the menu bar controls to pick your audio source and a visual style.

### macOS blocks it the first time

SoundPaper is signed but not notarized through Apple, so Gatekeeper flags it as an unidentified developer. 

**macOS Sonoma / Sequoia (14 & 15):** try to open it once (it'll be blocked), then go to **System Settings → Privacy & Security**, scroll to the blocked-app message, and click **Open Anyway**. Confirm once more when it relaunches.

**macOS Ventura and earlier:** right-click (or Control-click) the app and choose **Open**, then click **Open** in the dialog.

## Building from source

```bash
swift build                 # local debug build
./build_app.sh debug        # package as SoundPaper.app (native arch only)
./build_app.sh release      # package as a universal (arm64 + x86_64) SoundPaper.app
./make_dmg.sh               # package the release build into docs/SoundPaper.dmg
```

`build_app.sh` code-signs with a local self-signed identity (`SoundPaperCert`) for local development. Distributing to other people relies on the Gatekeeper bypass above rather than Apple notarization.
