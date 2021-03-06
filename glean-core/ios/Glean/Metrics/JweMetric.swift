/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

/// A representation of a JWE value.
public struct JweData {
    let header: String
    let key: String
    let initVector: String
    let cipherText: String
    let authTag: String
}

/// This implements the developer facing API for recording JWE metrics.
///
/// Instances of this class type are automatically generated by the parsers at build time,
/// allowing developers to record values that were previously registered in the metrics.yaml file.
///
/// The JWE API exposes the `JweMetricType.set(_:)` and `JweMetricType.setWithCompactRepresentation(_:)` methods,
/// which takes care of validating the input data.
public class JweMetricType {
    let handle: UInt64
    let disabled: Bool
    let sendInPings: [String]

    /// The public constructor used by automatically generated metrics.
    public init(category: String, name: String, sendInPings: [String], lifetime: Lifetime, disabled: Bool) {
        self.disabled = disabled
        self.sendInPings = sendInPings
        self.handle = withArrayOfCStrings(sendInPings) { pingArray in
            glean_new_jwe_metric(
                category,
                name,
                pingArray,
                Int32(sendInPings.count),
                lifetime.rawValue,
                disabled.toByte()
            )
        }
    }

    /// Destroy this metric.
    deinit {
        if self.handle != 0 {
            glean_destroy_jwe_metric(self.handle)
        }
    }

    /// Set a JWE value.
    ///
    /// - parameters:
    ///     * header: value The [`compact representation`](https://tools.ietf.org/html/rfc7516#appendix-A.2.7) of a JWE value.
    public func setWithCompactRepresentation(_ value: String) {
        guard !self.disabled else { return }

        Dispatchers.shared.launchAPI {
            glean_jwe_set_with_compact_representation(self.handle, value)
        }
    }

    /// Build a JWE value from it's elements and set to it.
    ///
    /// - parameters:
    ///     * header: A variable-size JWE protected header.
    ///     * key: A variable-size encrypted key.
    ///            This can be an empty octet sequence.
    ///     * initVector: A fixed-size, 96-bit, base64 encoded Jwe initialization vector.
    ///                   If not required by the encryption algorithm, can be an empty octet sequence.
    ///     * cipherText: The variable-size base64 encoded cipher text.
    ///     * authTag: A fixed-size, 132-bit, base64 encoded authentication tag.
    ///                Can be an empty octet sequence.
    public func set(_ header: String, _ key: String, _ initVector: String, _ cipherText: String, _ authTag: String) {
        guard !self.disabled else { return }

        Dispatchers.shared.launchAPI {
            glean_jwe_set(self.handle, header, key, initVector, cipherText, authTag)
        }
    }

    /// Tests whether a value is stored for the metric for testing purposes only. This function will
    /// attempt to await the last task (if any) writing to the the metric's storage engine before
    /// returning a value.
    ///
    /// - parameters:
    ///     * pingName: represents the name of the ping to retrieve the metric for.
    ///                 Defaults to the first value in `sendInPings`.
    /// - returns: true if metric value exists, otherwise false
    public func testHasValue(_ pingName: String? = nil) -> Bool {
        Dispatchers.shared.assertInTestingMode()

        let pingName = pingName ?? self.sendInPings[0]
        return glean_jwe_test_has_value(self.handle, pingName).toBool()
    }

    // swiftlint:disable force_cast
    /// Returns the stored value for testing purposes only. This function will attempt to await the
    /// last task (if any) writing to the the metric's storage engine before returning a value.
    ///
    /// Throws a "Missing value" exception if no value is stored.
    ///
    /// - parameters:
    ///     * pingName: represents the name of the ping to retrieve the metric for.
    ///                 Defaults to the first value in `sendInPings`.
    ///
    /// - returns:  value of the stored metric
    public func testGetValue(_ pingName: String? = nil) throws -> JweData {
        Dispatchers.shared.assertInTestingMode()

        let pingName = pingName ?? self.sendInPings[0]

        if !testHasValue(pingName) {
            throw "Missing value"
        }

        var data: JweData?

        let jsonString = String(freeingGleanString: glean_jwe_test_get_value_as_json_string(self.handle, pingName))
        if let jsonData: Data = jsonString.data(using: .utf8, allowLossyConversion: false) {
            if let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                data = JweData(
                    header: json["header"] as! String,
                    key: json["key"] as! String,
                    initVector: json["init_vector"] as! String,
                    cipherText: json["cipher_text"] as! String,
                    authTag: json["auth_tag"] as! String
                )
            }
        }

        return data!
    }

    // swiftlint:enable force_cast

    /// Returns the stored value in the compact representation for testing purposes only.
    /// This function will attempt to await the last task (if any)
    /// writing to the metric's storage engine before returning a value.
    ///
    /// Throws a "Missing value" exception if no value is stored.
    ///
    /// - parameters:
    ///     * pingName: represents the name of the ping to retrieve the metric for.
    ///                 Defaults to the first value in `sendInPings`.
    ///
    /// - returns:  value of the stored metric
    public func testGetCompactRepresentation(_ pingName: String? = nil) throws -> String {
        Dispatchers.shared.assertInTestingMode()

        let pingName = pingName ?? self.sendInPings[0]

        if !testHasValue(pingName) {
            throw "Missing value"
        }

        return String(freeingGleanString: glean_jwe_test_get_value(self.handle, pingName))
    }

    /// Returns the number of errors recorded for the given metric.
    ///
    /// - parameters:
    ///     * errorType: The type of error recorded.
    ///     * pingName: represents the name of the ping to retrieve the metric for.
    ///                 Defaults to the first value in `sendInPings`.
    ///
    /// - returns: The number of errors recorded for the metric for the given error type.
    public func testGetNumRecordedErrors(_ errorType: ErrorType, pingName: String? = nil) -> Int32 {
        Dispatchers.shared.assertInTestingMode()

        let pingName = pingName ?? self.sendInPings[0]

        return glean_jwe_test_get_num_recorded_errors(
            self.handle,
            errorType.rawValue,
            pingName
        )
    }
}
