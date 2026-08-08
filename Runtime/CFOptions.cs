using System.Collections.Generic;

namespace CausalFoundry.Unity
{
    /// <summary>Runtime options shared by the Android and iOS Core SDKs.</summary>
    public sealed class CFOptions
    {
        public CFOptions()
        {
            // The current iOS Core SDK can suppress processing when this is false, even after an
            // identify event. Keep this enabled unless pre-identify events must be discarded.
            AllowAnonymousUsers = true;
            UpdateImmediately = false;
            AutoShowInAppMessages = true;
            DisableAutoPageTracking = true;
            PauseSdk = false;
            EnableDebugMode = true;
        }

        /// <summary>
        /// Allows events before Identify. Defaults to true for consistent processing in the current
        /// iOS Core SDK. Disable only when anonymous activity must be suppressed.
        /// </summary>
        public bool AllowAnonymousUsers { get; set; }

        /// <summary>Asks the native SDK to submit accepted events immediately where supported.</summary>
        public bool UpdateImmediately { get; set; }

        public bool AutoShowInAppMessages { get; set; }

        /// <summary>
        /// Defaults to true because Unity navigation is not represented by native Activity or
        /// UIViewController page transitions.
        /// </summary>
        public bool DisableAutoPageTracking { get; set; }

        public bool PauseSdk { get; set; }

        public bool EnableDebugMode { get; set; }

        internal IDictionary<string, object> ToJsonObject()
        {
            return new Dictionary<string, object>
            {
                { "allow_anonymous_users", AllowAnonymousUsers },
                { "auto_show_in_app_messages", AutoShowInAppMessages },
                { "auto_track_pages", !DisableAutoPageTracking },
                { "disable_auto_page_tracking", DisableAutoPageTracking },
                { "enable_debug_mode", EnableDebugMode },
                { "pause_sdk", PauseSdk },
                { "update_immediately", UpdateImmediately }
            };
        }
    }

    /// <summary>
    /// Portable Core user catalog fields, also called user dimensions. Additional dimensions are
    /// string-valued because the pinned iOS Core SDK accepts string catalog metadata.
    /// </summary>
    public sealed class UserCatalogOptions
    {
        /// <summary>Full country name, such as Spain.</summary>
        public string Country { get; set; }

        /// <summary>Additional user dimensions that are not first-class fields, such as role.</summary>
        public IDictionary<string, string> Metadata { get; set; }

        internal IDictionary<string, object> ToJsonObject()
        {
            var result = new Dictionary<string, object>();
            if (Country != null)
            {
                result["country"] = Country;
            }
            if (Metadata != null)
            {
                result["meta"] = Metadata;
            }
            return result;
        }
    }

    /// <summary>Optional fields accepted by an Identify event.</summary>
    public sealed class IdentifyOptions
    {
        public string ReferralCode { get; set; }

        public string BlockedReason { get; set; }

        public string BlockedRemarks { get; set; }

        /// <summary>
        /// Additional event metadata. The SDK adds its UPM package version as
        /// <c>unity_version</c> to a copied dictionary.
        /// </summary>
        public IDictionary<string, object> Metadata { get; set; }

        /// <summary>Overrides the SDK-level upload preference for this event where supported.</summary>
        public bool? UpdateImmediately { get; set; }

        /// <summary>Optional Unix timestamp in milliseconds. Ignored by native SDKs that do not support it.</summary>
        public long? TimestampMilliseconds { get; set; }

        internal IDictionary<string, object> ToJsonObject()
        {
            var result = new Dictionary<string, object>();

            if (ReferralCode != null)
            {
                result["referral_code"] = ReferralCode;
            }

            if (BlockedReason != null)
            {
                result["blocked_reason"] = BlockedReason;
            }

            if (BlockedRemarks != null)
            {
                result["blocked_remarks"] = BlockedRemarks;
            }

            result["meta"] = CFSDK.CreateEventMetadata(Metadata);

            if (UpdateImmediately.HasValue)
            {
                result["immediate"] = UpdateImmediately.Value;
            }

            if (TimestampMilliseconds.HasValue)
            {
                result["timestamp_ms"] = TimestampMilliseconds.Value;
            }

            return result;
        }
    }

    /// <summary>Optional property and metadata for a custom Track event.</summary>
    public sealed class TrackOptions
    {
        /// <summary>A single primary value associated with the event.</summary>
        public string Property { get; set; }

        /// <summary>
        /// Additional primitive, list, or dictionary values associated with the event. The SDK
        /// adds its UPM package version as <c>unity_version</c> to a copied dictionary.
        /// </summary>
        public IDictionary<string, object> Metadata { get; set; }

        /// <summary>Overrides the SDK-level upload preference for this event where supported.</summary>
        public bool? UpdateImmediately { get; set; }

        /// <summary>Optional Unix timestamp in milliseconds. Ignored by native SDKs that do not support it.</summary>
        public long? TimestampMilliseconds { get; set; }

        internal IDictionary<string, object> ToJsonObject()
        {
            var result = new Dictionary<string, object>();

            if (Property != null)
            {
                result["property"] = Property;
            }

            result["meta"] = CFSDK.CreateEventMetadata(Metadata);

            if (UpdateImmediately.HasValue)
            {
                result["immediate"] = UpdateImmediately.Value;
            }

            if (TimestampMilliseconds.HasValue)
            {
                result["timestamp_ms"] = TimestampMilliseconds.Value;
            }

            return result;
        }
    }
}
