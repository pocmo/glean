/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/// This class represents a ping uploader via HTTP.
///
/// This will typically be invoked by the appropriate scheduling mechanism to upload a ping to the server.
public class HttpPingUploader {
    var config: Configuration

    // This struct is used for organizational purposes to keep the class constants in a single place
    struct Constants {
        // Since ping file names are UUIDs, this matches UUIDs for filtering purposes
        static let filePattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        static let logTag = "glean/HttpPingUploader"
        // NOTE: The `PINGS_DIR` must be kept in sync with the one in the Rust implementation.
        static let pingsDir = "pending_pings"
        static let connectionTimeout = 10000
    }

    private let logger = Logger(tag: Constants.logTag)

    public init(configuration: Configuration) {
        config = configuration
    }

    /// A function to aid in logging the ping to the console via `NSLog`.
    ///
    /// - parameters:
    ///     * path: The URL path to append to the server address
    ///     * data: The serialized text data to send
    func logPing(path: String, data: String) {
        logger.debug("Glean ping to URL: \(path)\n\(data)")
    }

    /// Synchronously upload a ping to Mozilla servers.
    ///
    /// - parameters:
    ///     * path: The URL path to append to the server address
    ///     * data: The serialized text data to send
    ///     * callback: A callback to return the success/failure of the upload
    ///
    /// Note that the `X-Client-Type`: `Glean` and `X-Client-Version`: <SDK version>
    /// headers are added to the HTTP request in addition to the UserAgent. This allows
    /// us to easily handle pings coming from Glean on the legacy Mozilla pipeline.
    func upload(path: String, data: String, callback: @escaping (Bool, Error?) -> Void) {
        if config.logPings {
            logPing(path: path, data: data)
        }

        if let request = buildRequest(path: path, data: data) {
            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? 0
                switch statusCode {
                case 200 ..< 300:
                    // Known success errors (2xx):
                    // 200 - OK. Request accepted into the pipeline.

                    // We treat all success codes as successful upload even though we only expect 200.
                    callback(true, nil)
                case 400 ..< 500:
                    // Known client (4xx) errors:
                    // 404 - not found - POST/PUT to an unknown namespace
                    // 405 - wrong request type (anything other than POST/PUT)
                    // 411 - missing content-length header
                    // 413 - request body too large (Note that if we have badly-behaved clients that
                    //       retry on 4XX, we should send back 202 on body/path too long).
                    // 414 - request path too long (See above)

                    // Something our client did is not correct. It's unlikely that the client is going
                    // to recover from this by re-trying again, so we just log an error and report a
                    // successful upload to the service.
                    callback(true, error)
                default:
                    // Known other errors:
                    // 500 - internal error

                    // For all other errors we log a warning and try again at a later time.
                    callback(false, error)
                }
            }
            task.resume()
        }
    }

    /// Internal function that builds the request used for uploading the pings.
    ///
    /// - parameters:
    ///     * path: The URL path to append to the server address
    ///     * data: The serialized text data to send
    ///     * callback: A callback to return the success/failure of the upload
    ///
    /// - returns: Optional `URLRequest` object with the configured headings set.
    func buildRequest(path: String, data: String) -> URLRequest? {
        if let url = URL(string: config.serverEndpoint + path) {
            var request = URLRequest(url: url)
            request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.addValue(config.userAgent, forHTTPHeaderField: "User-Agent")
            request.addValue(createDateHeaderValue(), forHTTPHeaderField: "Date")
            request.addValue("Glean", forHTTPHeaderField: "X-Client-Type")
            request.addValue(Configuration.getGleanVersion(), forHTTPHeaderField: "X-Client-Version")
            request.timeoutInterval = TimeInterval(Constants.connectionTimeout)
            request.httpMethod = "POST"
            request.httpBody = Data(data.utf8)
            request.httpShouldHandleCookies = false

            if let tag = config.pingTag {
                request.addValue(tag, forHTTPHeaderField: "X-Debug-ID")
            }

            return request
        }

        return nil
    }

    /// Helper function to format the date for the date header.
    ///
    /// - parameters:
    ///     * date: The date to convert
    ///
    /// - returns: `String` date in the correct format
    func createDateHeaderValue(date: Date = Date()) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.setLocalizedDateFormatFromTemplate("EEE, dd MMM yyyy HH:mm:ss z")
        return dateFormatter.string(from: date)
    }

    /// This function deserializes and processes all of the serialized ping files.
    ///
    /// This function will ignore files that don't match the UUID regex and just delete them to
    /// prevent files from polluting the ping storage directory.
    func process() {
        let pingDirectory = HttpPingUploader.getOrCreatePingDirectory()

        do {
            let storageDirectory = try FileManager.default.contentsOfDirectory(
                atPath: pingDirectory.relativePath
            )

            for file in storageDirectory {
                if file.lastPathComponent.matches(Constants.filePattern) {
                    logger.debug("Processing ping: \(file)")
                    processFile(pingDirectory.appendingPathComponent(file)) { success, error in
                        if !success {
                            self.logger.error("Error processing ping file: \(file)\n\(error.debugDescription)")
                        } else {
                            do {
                                try FileManager.default.removeItem(
                                    atPath: pingDirectory.appendingPathComponent(file).relativePath
                                )
                            } catch {
                                self.logger.error("Error deleting ping file: \(file)")
                            }
                        }
                    }
                } else {
                    // Delete files that don't match the UUID filePattern regex
                    logger.debug("Pattern mismatch. Deleting \(file)")
                    try FileManager.default.removeItem(
                        atPath: pingDirectory.appendingPathComponent(file).relativePath
                    )
                }
            }
        } catch {
            logger.error("Error while enumerating files in ping directory")
        }
    }

    /// This function encapsulates processing of a single ping file
    ///
    /// - parameters:
    ///   * file: The `URL` of the file to process
    ///   * callback: Allows for an action to occur as the result of the async upload operation
    func processFile(_ file: URL, callback: @escaping (Bool, Error?) -> Void) {
        do {
            let data = try String(contentsOfFile: file.relativePath, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)

            if lines.count >= 2 {
                let path = lines[0]
                let serializedPing = lines[1]

                self.upload(path: path, data: serializedPing, callback: callback)
            } else {
                logger.error("Error while processing ping file: \(file): File corrupted")
                callback(false, nil)
            }
        } catch {
            logger.error("Error while processing ping file: \(file): \(error.localizedDescription)")
            callback(false, nil)
        }
    }

    /// Helper function that will return the ping directory, or create it if it doesn't exist
    ///
    /// - returns: File `URL` representing the ping directory
    static func getOrCreatePingDirectory() -> URL {
        let dataPath = getDocumentsDirectory().appendingPathComponent(Constants.pingsDir)

        if !FileManager.default.fileExists(atPath: dataPath.relativePath) {
            do {
                try FileManager.default.createDirectory(
                    atPath: dataPath.relativePath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print(error.localizedDescription)
            }
        }

        return dataPath
    }
}
