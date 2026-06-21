![Banner](Images/banner.png?)

# EeveeSpotifyNext

**Spotify Premium + custom lyrics tweak for iOS — maintained for Spotify 9.1.x (tested on 9.1.58).**

This tweak makes Spotify think you have a Premium subscription, granting free listening just like Spotilife, and adds extra features such as custom lyrics.

> [!NOTE]
> The original EeveeSpotify repository was disabled by a [DMCA takedown](https://github.com/github/dmca/blob/master/2025/08/2025-08-14-spotify.md), so this repository does **not** ship IPA packages. You build your own from a decrypted Spotify IPA (see below).

## Supported version

- **Spotify 9.1.x** (tested on **9.1.58**, iOS 26).

On 9.1.x Spotify moved account/plan delivery to a UCS product-state push and pam-view-service Connect-RPC, so this fork restores Premium through those channels (the old request interception no longer applies on these versions). What works:

- Premium unlock (free listening, on-demand, no ads) from the first launch
- "Your plan" card and the **Premium** tab show your EeveeSpotify plan instead of upsells
- Custom lyrics

## Custom lyrics

Lyrics are provided by **Musixmatch** (time-synced). To use it, download Musixmatch from the App Store, sign up, go to **Settings → Get help → Copy debug info**, and paste it into the EeveeSpotify token prompt. You can also extract the token via MITM.

> Genius, LRCLIB and PetitLyrics providers exist in the code but are not the default on 9.1.x.

If a song can't be found or the lyrics can't be processed, you'll see "Couldn't load the lyrics for this song."

## Restrictions (server-sided — will **never** work)

- Very High audio quality
- Native playlist downloading (podcast episodes and local playlists do work)
- Jam (hosting/joining remotely)
- AI DJ / AI Playlist
- Spotify Connect (acts as a remote control / behaves as Free while connected)

## How to build the IPA (GitHub Actions)

> [!NOTE]
> First time only:
> 1. Fork this repository.
> 2. On your fork: **Settings → Actions** → enable **Read and write permissions**.

<details>
  <summary>Steps</summary>
  <ol>
    <li>If your fork is out of date, click <strong>Sync fork → Update branch</strong>.</li>
    <li>Go to the <strong>Actions</strong> tab → <strong>Create IPA Packages</strong> → <strong>Run workflow</strong>.</li>
    <li>Prepare a decrypted <code>.ipa</code> <em>(we cannot provide it for legal reasons)</em> and upload it to a file host (filebin.net, filemail.com, Dropbox, …). Paste the <strong>direct download link</strong> (not a webpage) into the field.</li>
    <li>Run the workflow and wait. Download the built IPA from your fork's <strong>Releases</strong>.</li>
  </ol>
</details>

## How to build locally (macOS)

Requires [Theos](https://theos.dev). The tweak depends on SwiftProtobuf; if your local Swift is newer than the prebuilt one, build it from source once:

```bash
export THEOS=~/theos
./setup-local-build.sh        # one-time: builds & installs SwiftProtobuf for your toolchain
make package                  # -> packages/com.eevee.spotify_*_iphoneos-arm.deb (+ extracted .dylib)
```

Helper scripts:

- `./build-ipa.sh <decrypted-spotify.ipa>` — build the `.deb` and inject it into a copy of your IPA (via [cyan](https://github.com/asdfzxcvbn/pyzule-rw)); output in `dist/`.
- `./build-lc.sh` — assemble a LiveContainer Tweaks folder (`dist/lc-spot/` + zip).

## Installation

Sideload the built IPA with **Sideloadly**, **ksign**, **AltStore**, or run it in **LiveContainer**. To open Spotify links in the sideloaded app, use [OpenSpotifySafariExtension](https://github.com/BillyCurtis/OpenSpotifySafariExtension) (activate it in Settings → Safari → Extensions).

## How it works

EeveeSpotify intercepts Spotify's account/configuration data and modifies it in real time so the app believes you have Premium. On 9.1.x this happens via the product-state push (`productStateUpdated`) and a `URLProtocol` that rewrites the pam-view-service plan responses.

## Credits

Based on the original [EeveeSpotify](https://github.com/whoeevee/EeveeSpotify) by **whoeevee/Eevee** and the Revived fork by **Meeep1/Skye**, plus all the localization contributors. 9.1.x compatibility work in this fork.

## Donations

USDC (ETH): `0x2Bf9F27FBa0eD37940819907a2e732523d4523C1`

BTC: `3NB6WhB8Krtncq6EnGCFoe35JKh9B1n6eC`
