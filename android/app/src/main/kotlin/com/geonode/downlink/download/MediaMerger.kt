package com.geonode.downlink.download

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/** Remuxes a video-only file and an audio-only file into one MP4 (no re-encode). */
object MediaMerger {
    fun merge(videoPath: String, audioPath: String, outputPath: String) {
        val videoFile = File(videoPath)
        val audioFile = File(audioPath)
        require(videoFile.exists()) { "Video file missing: $videoPath" }
        require(audioFile.exists()) { "Audio file missing: $audioPath" }

        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) {
            outputFile.delete()
        }

        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            videoExtractor.setDataSource(videoPath)
            audioExtractor.setDataSource(audioPath)

            val videoTrack = selectTrack(videoExtractor, "video/")
                ?: error("No video track in $videoPath")
            val audioTrack = selectTrack(audioExtractor, "audio/")
                ?: error("No audio track in $audioPath")

            videoExtractor.selectTrack(videoTrack)
            audioExtractor.selectTrack(audioTrack)

            val videoFormat = videoExtractor.getTrackFormat(videoTrack)
            val audioFormat = audioExtractor.getTrackFormat(audioTrack)

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val outVideo = muxer.addTrack(videoFormat)
            val outAudio = muxer.addTrack(audioFormat)
            muxer.start()

            copyTrack(videoExtractor, muxer, outVideo, videoFormat)
            copyTrack(audioExtractor, muxer, outAudio, audioFormat)

            muxer.stop()
        } finally {
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            videoExtractor.release()
            audioExtractor.release()
        }

        if (!outputFile.exists() || outputFile.length() == 0L) {
            error("Merged output was not created")
        }
    }

    private fun selectTrack(extractor: MediaExtractor, mimePrefix: String): Int? {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(mimePrefix)) return i
        }
        return null
    }

    private fun copyTrack(
        extractor: MediaExtractor,
        muxer: MediaMuxer,
        trackIndex: Int,
        format: MediaFormat,
    ) {
        val maxSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
            format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(256 * 1024)
        } else {
            1024 * 1024
        }
        val buffer = ByteBuffer.allocateDirect(maxSize)
        val info = MediaCodec.BufferInfo()

        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break

            info.offset = 0
            info.size = sampleSize
            info.presentationTimeUs = extractor.sampleTime.coerceAtLeast(0L)
            info.flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                extractor.sampleFlags
            } else {
                0
            }

            muxer.writeSampleData(trackIndex, buffer, info)
            extractor.advance()
        }
    }
}
