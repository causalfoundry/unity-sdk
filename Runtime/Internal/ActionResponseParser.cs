using System;
using System.Collections.Generic;
using System.Globalization;

namespace CausalFoundry.Unity.Internal
{
    internal static class ActionResponseParser
    {
        internal static bool TryParseActions(
            string json,
            out IList<CFAction> actions,
            out string error)
        {
            actions = new List<CFAction>();
            if (string.IsNullOrEmpty(json))
            {
                error = null;
                return true;
            }

            object root;
            if (!CFJson.TryDeserialize(json, out root, out error))
            {
                return false;
            }

            IList<object> items = root as IList<object>;
            IDictionary<string, object> rootObject = root as IDictionary<string, object>;
            if (items == null && rootObject != null)
            {
                object data;
                if (rootObject.TryGetValue("data", out data))
                {
                    items = data as IList<object>;
                    if (items == null)
                    {
                        error = "The action response 'data' value must be an array.";
                        return false;
                    }
                }
                else
                {
                    items = new List<object> { rootObject };
                }
            }

            if (items == null)
            {
                error = "The action response must be an array or an object containing a data array.";
                return false;
            }

            var parsed = new List<CFAction>(items.Count);
            for (int i = 0; i < items.Count; i++)
            {
                IDictionary<string, object> item = items[i] as IDictionary<string, object>;
                if (item == null)
                {
                    error = "Action item " + i + " must be a JSON object.";
                    return false;
                }

                CFAction action;
                if (!TryParseAction(item, out action, out error))
                {
                    error = "Action item " + i + ": " + error;
                    return false;
                }

                parsed.Add(action);
            }

            actions = parsed;
            error = null;
            return true;
        }

        internal static bool TryParseOpenedAction(
            string json,
            out ActionOpenedEvent openedAction,
            out string error)
        {
            openedAction = null;
            object parsed;
            if (!CFJson.TryDeserialize(json, out parsed, out error))
            {
                return false;
            }

            IDictionary<string, object> source = parsed as IDictionary<string, object>;
            if (source == null)
            {
                error = "Action-open attributes must be a JSON object.";
                return false;
            }

            var attributes = new Dictionary<string, string>(source.Count, StringComparer.Ordinal);
            foreach (KeyValuePair<string, object> pair in source)
            {
                attributes[pair.Key] = ValueAsString(pair.Value);
            }

            string ctaType;
            string ctaId;
            attributes.TryGetValue("cta_type", out ctaType);
            attributes.TryGetValue("cta_id", out ctaId);
            openedAction = new ActionOpenedEvent(ctaType, ctaId, attributes);
            error = null;
            return true;
        }

        private static bool TryParseAction(
            IDictionary<string, object> item,
            out CFAction action,
            out string error)
        {
            action = new CFAction
            {
                Raw = item,
                UserId = GetString(item, "user_id"),
                QueuedAt = GetString(item, "queued_at")
            };

            object payloadValue;
            IDictionary<string, object> payload = null;
            if (item.TryGetValue("payload", out payloadValue) && payloadValue != null)
            {
                payload = payloadValue as IDictionary<string, object>;
                if (payload == null)
                {
                    error = "The payload value must be an object or null.";
                    return false;
                }
            }
            else if (item.ContainsKey("type") || item.ContainsKey("render_method") ||
                     item.ContainsKey("content"))
            {
                // Some native versions encode NudgeResponseItem.payload directly.
                payload = item;
            }

            if (payload != null)
            {
                CFActionPayload parsedPayload;
                if (!TryParsePayload(payload, out parsedPayload, out error))
                {
                    return false;
                }

                action.Payload = parsedPayload;
            }

            object errorValue;
            if (item.TryGetValue("error", out errorValue) && !IsEmptyError(errorValue))
            {
                action.Error = ParseItemError(errorValue);
            }

            error = null;
            return true;
        }

        private static bool TryParsePayload(
            IDictionary<string, object> payload,
            out CFActionPayload result,
            out string error)
        {
            result = new CFActionPayload
            {
                Raw = payload,
                Type = GetString(payload, "type"),
                RenderMethod = GetString(payload, "render_method"),
                DeliveryMode = GetString(payload, "delivery_mode")
            };

            object contentValue;
            if (payload.TryGetValue("content", out contentValue) && contentValue != null)
            {
                IDictionary<string, object> content = contentValue as IDictionary<string, object>;
                if (content == null)
                {
                    error = "The payload content value must be an object or null.";
                    return false;
                }

                result.Content = new CFActionContent
                {
                    Values = content,
                    Title = GetString(content, "title"),
                    Body = GetString(content, "body")
                };
            }

            result.Attributes = GetDictionary(payload, "attr");
            if (result.Attributes == null)
            {
                result.Attributes = GetDictionary(payload, "attributes");
            }

            result.Internal = GetDictionary(payload, "internal");

            object tagsValue;
            if (payload.TryGetValue("tags", out tagsValue) && tagsValue != null)
            {
                IList<object> rawTags = tagsValue as IList<object>;
                if (rawTags == null)
                {
                    error = "The payload tags value must be an array or null.";
                    return false;
                }

                var tags = new List<string>(rawTags.Count);
                for (int i = 0; i < rawTags.Count; i++)
                {
                    tags.Add(ValueAsString(rawTags[i]));
                }

                result.Tags = tags;
            }

            error = null;
            return true;
        }

        private static CFError ParseItemError(object value)
        {
            IDictionary<string, object> errorObject = value as IDictionary<string, object>;
            if (errorObject == null)
            {
                return new CFError(
                    CFErrorCode.NativeFailure,
                    ValueAsString(value),
                    string.Empty);
            }

            string code = GetString(errorObject, "code");
            string message = GetString(errorObject, "message");
            if (string.IsNullOrEmpty(message))
            {
                message = ValueAsString(value);
            }

            return new CFError(CFErrorCode.NativeFailure, message, code);
        }

        private static bool IsEmptyError(object value)
        {
            if (value == null)
            {
                return true;
            }

            string text = value as string;
            if (text != null)
            {
                return string.IsNullOrEmpty(text.Trim());
            }

            IDictionary<string, object> errorObject = value as IDictionary<string, object>;
            return errorObject != null && errorObject.Count == 0;
        }

        private static IDictionary<string, object> GetDictionary(
            IDictionary<string, object> source,
            string key)
        {
            object value;
            return source.TryGetValue(key, out value) ? value as IDictionary<string, object> : null;
        }

        private static string GetString(IDictionary<string, object> source, string key)
        {
            object value;
            return source.TryGetValue(key, out value) ? ValueAsString(value) : null;
        }

        private static string ValueAsString(object value)
        {
            if (value == null)
            {
                return null;
            }

            string text = value as string;
            if (text != null)
            {
                return text;
            }

            if (value is bool)
            {
                return (bool)value ? "true" : "false";
            }

            if (value is IFormattable)
            {
                return ((IFormattable)value).ToString(null, CultureInfo.InvariantCulture);
            }

            string json;
            string error;
            return CFJson.TrySerialize(value, out json, out error) ? json : value.ToString();
        }
    }
}
