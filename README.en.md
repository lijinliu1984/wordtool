# Crazy Code Word Helper

## Project Overview

Crazy Code Word Helper is an open-source cross-platform vocabulary learning app built on a **Flutter client + Rust server** architecture:

- **Client** (Flutter): Supports Android, iOS, Windows, macOS, Linux, and Web. Handles UI interaction and local learning data.
- **Server** (Rust + axum): Handles word bank distribution, version management, and static asset hosting (images/audio).

The app organizes word banks in a three-level structure (Level → Category → Word), ships with multiple practice modes, and uses a "Practice → Test → Review" loop to boost memorization.

## Features

- **Three-Level Word Bank Management**: Level → Category → Word, browse the word bank level by level
- **Multimedia Support**: Each word can have an associated audio file (listening) and image (visual memory), hosted by the server and loaded on demand
- **Online Word Bank Updates**: Checks the server for a newer word bank version on startup and downloads it in one tap — no app reinstall needed
- **Six Practice Modes**:
  - Translation Practice (view learn-word, choose my-word)
  - Listening Practice A (listen to audio, choose image)
  - Listening Practice B (listen to audio, choose my-word)
  - Dictation Practice A (listen to audio, type learn-word)
  - Dictation Practice B (view image, type learn-word)
  - Dictation Practice C (view my-word, type learn-word)
- **Practice Records**: Automatically saves accuracy rate and per-question details for each practice session, with full history review
- **Local Learning Data**: Tasks and practice records are stored locally in SQLite, while word banks, images, and audio are served by the backend

## Client Screenshots

| Home | Home (Learning) | Word Square |
|:---:|:---:|:---:|
| ![Home](images/client-home.png) | ![Home - Learning](images/client-home-show-test-button.png) | ![Word Square](images/client-word-square.png) |

| All Categories | Word List | Create Task |
|:---:|:---:|:---:|
| ![All Categories](images/client-hot-classify.png) | ![Word List](images/client-word-list.png) | ![Create Task](images/client-create-task.png) |

| Word Practice | Today's Words | Word Game |
|:---:|:---:|:---:|
| ![Word Practice](images/client-word-practice.png) | ![Today's Words](images/client-word-practice-end.png) | ![Word Game](images/client-word-game.png) |

| Dictation Test | Test Result | Practice History |
|:---:|:---:|:---:|
| ![Dictation Test](images/client-word-testing.png) | ![Test Result](images/client-word-test-result.png) | ![Practice History](images/client-word-practice-record-list.png) |

## Server

The server is built with **Rust + [axum](https://github.com/tokio-rs/axum)**, providing word bank distribution and static asset hosting for the client.

### API

| Endpoint | Description |
|----------|-------------|
| `GET /api/version?version_code={n}` | Version check. Reads the latest version from the `version_info` table and compares it with the client, returning whether an update exists and what changed |
| `GET /api/download` | Word bank download. Returns the full `vocabulary_study.db` file, which the client uses to replace its local word bank |
| `POST /api/word/image` | Word image upload. Accepts `word_id` and `file` via multipart, writes the cropped PNG to `resources/pic`, and updates the image field in the word bank |
| `GET /resources/{filename}` | Static asset hosting. Serves word images and audio files, loaded on demand by the client |

### Configuration

The server is configured through environment variables, all with sensible defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Listen address |
| `PORT` | `3002` | Listen port |
| `DB_PATH` | `sqlite/vocabulary_study.db` | Path to the word bank database |
| `RESOURCES_DIR` | `resources` | Static asset directory |
| `DB_VERSION` | `1.0.0` | Word bank version |

### Running

```bash
cd server--rust
cargo build --release
cd target/release
./wordtool-server          # Linux / macOS; use wordtool-server.exe on Windows
```

The working directory must contain the word bank and the resource directories:

```
target/release/
├── wordtool-server(.exe)
├── sqlite/
│   └── vocabulary_study.db   # Word bank database
└── resources/
    ├── pic/                  # Word images
    └── audio/                # Word audio
```

### Server Screenshots

| Server Startup | Word Bank Database |
|:---:|:---:|
| ![Server Startup](images/server-start.png) | ![Word Bank Database](images/server-sqlite-path.png) |

| Image Resources | Audio Resources |
|:---:|:---:|
| ![Image Resources](images/server-pic-path.png) | ![Audio Resources](images/server-audio-path.png) |

### Connecting the Client to a Self-Hosted Server

If you deploy the server yourself, you can point the client at it under "Settings (top-right of the home screen) → Server Address" — enter your server address (e.g. `http://192.168.1.60:3002`) and tap "Test Connection" to confirm before saving. All API requests will then use the new address. The client connects to `https://wt.fmcode.top` by default.

| Server Address |
|:---:|
| ![Server Address](images/client-edit-serverUrl.png) |

## Installation

1. Make sure you have [Flutter](https://docs.flutter.dev/get-started/install) installed
2. After cloning the repo, run:
   ```bash
   flutter pub get
   flutter run
   ```
3. Build for release:
   ```bash
   flutter build apk        # Android
   flutter build ios        # iOS (requires macOS + Xcode)
   flutter build windows    # Windows
   flutter build macos      # macOS
   ```

## Direct Download

| Scan to Download |
|:---:|
| ![Download QR](readme/download_QRCode_420.png) |

## Audio Download

The word audio used by the app is generated with **Alibaba Cloud Bailian (CosyVoice)** text-to-speech, and is available from the netdisks below:

| Baidu Netdisk | Quark Netdisk |
|:---:|:---:|
| audios | audios |
| [Open Link](https://pan.baidu.com/s/1dAJIgtLt7IIegjy9dDSRtA?pwd=3dr2) | [Open Link](https://pan.quark.cn/s/017d948ddff6?pwd=iKev) |
| Code: `3dr2` | Code: `iKev` |

## Data Sources & Notes

| Content | Source | Download |
|---------|--------|----------|
| Word data | Compiled from the open-source [ECDict](https://github.com/skywind3000/ECDict) dictionary (MIT), including phonetics, definitions, Collins/Oxford flags, and BNC/COCA frequency | Bundled with the word bank |
| Word audio | Synthesized with Alibaba Cloud Bailian (CosyVoice) | Provided, see "Audio Download" above |
| Word images | Obtained from the web for testing only, used for functional demos | **Not provided** |

> Images used in this project are for functional testing and demonstration only. Copyright belongs to their original authors; this project neither redistributes them nor provides them for download. Replace them with properly licensed assets for production use.

## Contact

Feel free to reach out if you have any questions or suggestions:

| WeChat | QQ |
|:---:|:---:|
| ![WeChat QR](readme/wechat-qr.png) | ![QQ QR](readme/qq-qr.png) |

## Tech Stack

### Client (Flutter)

- [Flutter](https://flutter.dev/) - Cross-platform UI framework
- [sqflite](https://pub.dev/packages/sqflite) - Local SQLite database
- [dio](https://pub.dev/packages/dio) - HTTP requests
- [audioplayers](https://pub.dev/packages/audioplayers) - Audio playback
- [record](https://pub.dev/packages/record) - Audio recording (read-aloud practice)
- [cached_network_image](https://pub.dev/packages/cached_network_image) - Network image loading and caching
- [image_picker](https://pub.dev/packages/image_picker) - Image picking / camera
- [image](https://pub.dev/packages/image) - Image cropping
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local key-value storage
- [permission_handler](https://pub.dev/packages/permission_handler) - Permission requests

### Server (Rust)

- [axum](https://github.com/tokio-rs/axum) - Web framework
- [tokio](https://tokio.rs/) - Async runtime
- [rusqlite](https://github.com/rusqlite/rusqlite) - SQLite access
- [tower-http](https://github.com/tower-rs/tower-http) - Static file serving and CORS
- [serde](https://serde.rs/) / [serde_json](https://github.com/serde-rs/json) - Serialization

## License

Released under the [Boost Software License 1.0](LICENSE). You are free to use, modify, and distribute this software, including for commercial purposes (and in closed-source form), provided the original copyright and license notices are retained. See [LICENSE](LICENSE) for details.