﻿// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

using Mozilla.Glean.FFI;
using System;
using System.Text.Json;

namespace Mozilla.Glean.Private
{
    /// <summary>
    /// This implements the developer facing API for recording string list metrics.
    ///
    /// Instances of this class type are automatically generated by the parsers at build time,
    /// allowing developers to record values that were previously registered in the metrics.yaml file.
    ///
    /// The internal constructor is only used by [LabeledMetricType] directly.
    /// </summary>
    public sealed class StringListMetricType
    {
        private readonly bool disabled;
        private readonly string[] sendInPings;
        private readonly UInt64 handle;

        public StringListMetricType(
            bool disabled,
            string category,
            Lifetime lifetime,
            string name,
            string[] sendInPings
            ) : this(0, disabled, sendInPings)
        {
            handle = LibGleanFFI.glean_new_string_list_metric(
                    category: category,
                    name: name,
                    send_in_pings: sendInPings,
                    send_in_pings_len: sendInPings.Length,
                    lifetime: (int)lifetime,
                    disabled: disabled);
        }

        internal StringListMetricType(
            UInt64 handle,
            bool disabled,
            string[] sendInPings
            )
        {
            this.disabled = disabled;
            this.sendInPings = sendInPings;
            this.handle = handle;
        }

        /// <summary>
        /// Appends a string value to one or more string list metric stores.
        /// If the length of the string exceeds the maximum length, it will be truncated.
        /// </summary>
        /// <param name="value">This is a user defined string value.</param>
        public void Add(string value)
        {
            if (disabled)
            {
                return;
            }

            Dispatchers.LaunchAPI(() => {
                LibGleanFFI.glean_string_list_add(
                    this.handle, value);
            });
        }

        /// <summary>
        /// Sets a string list to one or more metric stores.
        /// If the length of the string exceeds the maximum length, it will be truncated.
        /// </summary>
        /// <param name="value">This is a user defined string list.</param>
        public void Set(string[] value)
        {
            if (disabled)
            {
                return;
            }

            Dispatchers.LaunchAPI(() => {
                SetSync(value);
            });
        }

        /// <summary>
        /// Sets a string list to one or more metric stores in a synchronous way.
        /// This is only to be used for the glean-ac to glean-core data migration.
        /// </summary>
        /// <param name="value">This is a user defined string list.</param>
        internal void SetSync(string[] value)
        {
            if (disabled)
            {
                return;
            }

            LibGleanFFI.glean_string_list_set(
                        this.handle,
                        value,
                        value.Length);
        }

        /// <summary>
        /// Tests whether a value is stored for the metric for testing purposes only. This function will
        /// attempt to await the last task(if any) writing to the the metric's storage engine before
        /// returning a value.
        /// </summary>
        /// <param name="pingName"> represents the name of the ping to retrieve the metric for.
        /// Defaults to the first value in `sendInPings`.</param>
        /// <returns>true if metric value exists, otherwise false</returns>
        public bool TestHasValue(string pingName = null)
        {
            Dispatchers.AssertInTestingMode();

            string ping = pingName ?? sendInPings[0];
            return LibGleanFFI.glean_string_list_test_has_value(this.handle, ping) != 0;
        }

        /// <summary>
        /// Returns the stored value for testing purposes only. This function will attempt to await the
        /// last task(if any) writing to the the metric's storage engine before returning a value.
        /// </summary>
        /// <param name="pingName">represents the name of the ping to retrieve the metric for.
        /// Defaults to the first value in `sendInPings`.</param>
        /// <returns>value of the stored metric</returns>
        /// <exception cref="System.NullReferenceException">Thrown when the metric contains no value</exception>
        public string[] TestGetValue(string pingName = null)
        {
            Dispatchers.AssertInTestingMode();

            if (!TestHasValue(pingName))
            {
                throw new NullReferenceException();
            }

            string ping = pingName ?? sendInPings[0];
          
            JsonDocument jsonPayload = JsonDocument.Parse(
                LibGleanFFI.glean_string_list_test_get_value_as_json_string(this.handle, ping).AsString()
            );
            JsonElement root = jsonPayload.RootElement;
            return JsonSerializer.Deserialize<string[]>(root.ToString());
        }

        /// <summary>
        /// Returns the number of errors recorded for the given metric.
        /// </summary>
        /// <param name="errorType">The type of the error recorded.</param>
        /// <param name="pingName">represents the name of the ping to retrieve the metric for.
        /// Defaults to the first value in `sendInPings`.</param>
        /// <returns>the number of errors recorded for the metric.</returns>
        public int TestGetNumRecordedErrors(Testing.ErrorType errorType, string pingName = null)
        {
            Dispatchers.AssertInTestingMode();

            string ping = pingName ?? sendInPings[0];
            return LibGleanFFI.glean_string_list_test_get_num_recorded_errors(
                this.handle, (int)errorType, ping
            );
        }
    }
}
