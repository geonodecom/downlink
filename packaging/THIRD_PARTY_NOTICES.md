# Third-Party Notices

Geonode Download Manager release builds may bundle the following third-party
tools in the `bin/` directory (desktop) or as Android `jniLibs` (`libffmpeg.so`):

## aria2

- Project: https://github.com/aria2/aria2
- License: GPL-2.0-or-later
- Used for direct HTTP/HTTPS segmented downloads and BitTorrent (magnet / `.torrent`) on desktop.

## yt-dlp

- Project: https://github.com/yt-dlp/yt-dlp
- License: Unlicense
- Used for YouTube metadata extraction and downloads on **desktop**.
- Android uses `youtube_explode_dart` instead (no yt-dlp process).

## ffmpeg

- Project: https://ffmpeg.org/
- License: GPL-2.0-or-later / LGPL-2.1-or-later (depending on build)
- Used to mux combined YouTube video and audio streams.
- Desktop builds typically use [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds).
- Android builds use static binaries from [Tyrrrz/FFmpegBin](https://github.com/Tyrrrz/FFmpegBin).

## libtorrent4j

- Project: https://github.com/aldenml/libtorrent4j
- License: MIT (with underlying libtorrent BSD license)
- Used for magnet and `.torrent` downloads on **Android**.

## Source code

Corresponding source code for GPL-licensed components is available from the
project URLs above. If you received a binary release and need matching source
for ffmpeg or aria2, contact the project maintainer or obtain source from the
official project sites listed above.
