package com.geonode.downlink.download

data class DownloadTask(
    val gid: String,
    val url: String,
    var fileName: String,
    val directory: String,
    val split: Int,
    val headers: Map<String, String>,
    var status: String,
    var totalLength: Long,
    var completedLength: Long,
    var downloadSpeed: Long,
    var uploadSpeed: Long = 0,
    var connections: Int,
    var pieceLength: Long,
    var numPieces: Int,
    var bitfield: String?,
    var errorMessage: String?,
    var contentUri: String?,
    var partPath: String?,
    var queuePosition: Int,
    val createdAt: Long,
    var updatedAt: Long,
    var isTorrent: Boolean = false,
) {
    fun toStatusMap(): Map<String, Any?> {
        // Never report the temp `{gid}.part` path — Dart derives the display
        // name from the last path segment and would overwrite the real title.
        val path = contentUri ?: FilePathHint(directory, fileName)
        return mapOf(
            "gid" to gid,
            "status" to status,
            "totalLength" to totalLength.toString(),
            "completedLength" to completedLength.toString(),
            "downloadSpeed" to downloadSpeed.toString(),
            "uploadSpeed" to uploadSpeed.toString(),
            "connections" to connections.toString(),
            "pieceLength" to pieceLength.toString(),
            "numPieces" to numPieces.toString(),
            "bitfield" to bitfield,
            "errorCode" to if (status == "error") "1" else null,
            "errorMessage" to errorMessage,
            "files" to listOf(
                mapOf(
                    "path" to path,
                    "length" to totalLength.toString(),
                    "completedLength" to completedLength.toString(),
                    "uris" to listOf(mapOf("uri" to url)),
                ),
            ),
        )
    }

    private fun FilePathHint(directory: String, fileName: String): String {
        if (directory.isBlank()) return fileName
        return "$directory${java.io.File.separator}$fileName"
    }
}
