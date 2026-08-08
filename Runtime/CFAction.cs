using System.Collections.Generic;

namespace CausalFoundry.Unity
{
    /// <summary>One action returned by FetchActions.</summary>
    public sealed class CFAction
    {
        internal CFAction()
        {
        }

        public string UserId { get; internal set; }

        public CFActionPayload Payload { get; internal set; }

        /// <summary>An item-level error included in an otherwise valid native response.</summary>
        public CFError Error { get; internal set; }

        /// <summary>ISO-8601 queue time when supplied by the native SDK.</summary>
        public string QueuedAt { get; internal set; }

        /// <summary>The complete decoded item, including fields added by future native SDKs.</summary>
        public IDictionary<string, object> Raw { get; internal set; }
    }

    public sealed class CFActionPayload
    {
        internal CFActionPayload()
        {
        }

        public string Type { get; internal set; }

        public string RenderMethod { get; internal set; }

        public string DeliveryMode { get; internal set; }

        public CFActionContent Content { get; internal set; }

        public IDictionary<string, object> Attributes { get; internal set; }

        public IList<string> Tags { get; internal set; }

        /// <summary>Opaque action identifiers and expiry information used by the native SDK.</summary>
        public IDictionary<string, object> Internal { get; internal set; }

        /// <summary>The complete decoded payload, including fields added by future native SDKs.</summary>
        public IDictionary<string, object> Raw { get; internal set; }
    }

    public sealed class CFActionContent
    {
        internal CFActionContent()
        {
        }

        public string Title { get; internal set; }

        public string Body { get; internal set; }

        /// <summary>The complete content object, including custom fields.</summary>
        public IDictionary<string, object> Values { get; internal set; }
    }

    /// <summary>Data emitted when a native in-app or notification action is opened.</summary>
    public sealed class ActionOpenedEvent
    {
        internal ActionOpenedEvent(
            string ctaType,
            string ctaId,
            IDictionary<string, string> attributes)
        {
            CtaType = ctaType;
            CtaId = ctaId;
            Attributes = attributes;
        }

        public string CtaType { get; private set; }

        public string CtaId { get; private set; }

        /// <summary>All string attributes supplied by the native Core SDK.</summary>
        public IDictionary<string, string> Attributes { get; private set; }
    }
}
