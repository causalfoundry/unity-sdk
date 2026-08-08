using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace CausalFoundry.Unity.Internal
{
    /// <summary>
    /// Small JSON codec for bridge payloads. It intentionally supports only dictionaries with
    /// string keys, lists, strings, booleans, null, and numeric primitives. It uses no reflection,
    /// dynamic code, or platform-specific serializer and is safe for IL2CPP/AOT builds.
    /// </summary>
    internal static class CFJson
    {
        private const int MaximumDepth = 64;

        internal static bool TrySerialize(object value, out string json, out string error)
        {
            var builder = new StringBuilder(128);
            if (!TryWriteValue(builder, value, 0, out error))
            {
                json = null;
                return false;
            }

            json = builder.ToString();
            error = null;
            return true;
        }

        internal static bool TryDeserialize(string json, out object value, out string error)
        {
            if (json == null)
            {
                value = null;
                error = "JSON cannot be null.";
                return false;
            }

            var parser = new Parser(json);
            return parser.TryParse(out value, out error);
        }

        private static bool TryWriteValue(
            StringBuilder builder,
            object value,
            int depth,
            out string error)
        {
            if (depth > MaximumDepth)
            {
                error = "JSON nesting exceeds " + MaximumDepth + " levels.";
                return false;
            }

            if (value == null)
            {
                builder.Append("null");
                error = null;
                return true;
            }

            string stringValue = value as string;
            if (stringValue != null)
            {
                WriteString(builder, stringValue);
                error = null;
                return true;
            }

            if (value is char)
            {
                WriteString(builder, value.ToString());
                error = null;
                return true;
            }

            if (value is bool)
            {
                builder.Append((bool)value ? "true" : "false");
                error = null;
                return true;
            }

            IDictionary<string, object> objectDictionary = value as IDictionary<string, object>;
            if (objectDictionary != null)
            {
                return TryWriteObjectDictionary(builder, objectDictionary, depth, out error);
            }

            IDictionary<string, string> stringDictionary = value as IDictionary<string, string>;
            if (stringDictionary != null)
            {
                return TryWriteStringDictionary(builder, stringDictionary, depth, out error);
            }

            IDictionary dictionary = value as IDictionary;
            if (dictionary != null)
            {
                return TryWriteDictionary(builder, dictionary, depth, out error);
            }

            IList list = value as IList;
            if (list != null)
            {
                return TryWriteList(builder, list, depth, out error);
            }

            if (TryWriteNumber(builder, value, out error))
            {
                return true;
            }

            if (error != null)
            {
                return false;
            }

            error = "Unsupported JSON value type: " + value.GetType().FullName + ".";
            return false;
        }

        private static bool TryWriteDictionary(
            StringBuilder builder,
            IDictionary dictionary,
            int depth,
            out string error)
        {
            var keys = new List<string>(dictionary.Count);
            foreach (DictionaryEntry entry in dictionary)
            {
                string key = entry.Key as string;
                if (key == null)
                {
                    error = "JSON object keys must be strings.";
                    return false;
                }

                keys.Add(key);
            }

            keys.Sort(StringComparer.Ordinal);
            builder.Append('{');

            for (int i = 0; i < keys.Count; i++)
            {
                if (i != 0)
                {
                    builder.Append(',');
                }

                string key = keys[i];
                WriteString(builder, key);
                builder.Append(':');
                if (!TryWriteValue(builder, dictionary[key], depth + 1, out error))
                {
                    return false;
                }
            }

            builder.Append('}');
            error = null;
            return true;
        }

        private static bool TryWriteObjectDictionary(
            StringBuilder builder,
            IDictionary<string, object> dictionary,
            int depth,
            out string error)
        {
            var keys = new List<string>(dictionary.Keys);
            keys.Sort(StringComparer.Ordinal);
            builder.Append('{');

            for (int i = 0; i < keys.Count; i++)
            {
                if (i != 0)
                {
                    builder.Append(',');
                }

                string key = keys[i];
                if (key == null)
                {
                    error = "JSON object keys cannot be null.";
                    return false;
                }

                WriteString(builder, key);
                builder.Append(':');
                if (!TryWriteValue(builder, dictionary[key], depth + 1, out error))
                {
                    return false;
                }
            }

            builder.Append('}');
            error = null;
            return true;
        }

        private static bool TryWriteStringDictionary(
            StringBuilder builder,
            IDictionary<string, string> dictionary,
            int depth,
            out string error)
        {
            var keys = new List<string>(dictionary.Keys);
            keys.Sort(StringComparer.Ordinal);
            builder.Append('{');

            for (int i = 0; i < keys.Count; i++)
            {
                if (i != 0)
                {
                    builder.Append(',');
                }

                string key = keys[i];
                if (key == null)
                {
                    error = "JSON object keys cannot be null.";
                    return false;
                }

                WriteString(builder, key);
                builder.Append(':');
                if (!TryWriteValue(builder, dictionary[key], depth + 1, out error))
                {
                    return false;
                }
            }

            builder.Append('}');
            error = null;
            return true;
        }

        private static bool TryWriteList(
            StringBuilder builder,
            IList list,
            int depth,
            out string error)
        {
            builder.Append('[');
            for (int i = 0; i < list.Count; i++)
            {
                if (i != 0)
                {
                    builder.Append(',');
                }

                if (!TryWriteValue(builder, list[i], depth + 1, out error))
                {
                    return false;
                }
            }

            builder.Append(']');
            error = null;
            return true;
        }

        private static bool TryWriteNumber(StringBuilder builder, object value, out string error)
        {
            if (value is float)
            {
                float number = (float)value;
                if (float.IsNaN(number) || float.IsInfinity(number))
                {
                    error = "JSON cannot represent NaN or infinity.";
                    return false;
                }

                builder.Append(number.ToString("R", CultureInfo.InvariantCulture));
                error = null;
                return true;
            }

            if (value is double)
            {
                double number = (double)value;
                if (double.IsNaN(number) || double.IsInfinity(number))
                {
                    error = "JSON cannot represent NaN or infinity.";
                    return false;
                }

                builder.Append(number.ToString("R", CultureInfo.InvariantCulture));
                error = null;
                return true;
            }

            if (value is decimal || value is byte || value is sbyte || value is short ||
                value is ushort || value is int || value is uint || value is long || value is ulong)
            {
                builder.Append(Convert.ToString(value, CultureInfo.InvariantCulture));
                error = null;
                return true;
            }

            error = null;
            return false;
        }

        private static void WriteString(StringBuilder builder, string value)
        {
            builder.Append('"');
            for (int i = 0; i < value.Length; i++)
            {
                char character = value[i];
                switch (character)
                {
                    case '"':
                        builder.Append("\\\"");
                        break;
                    case '\\':
                        builder.Append("\\\\");
                        break;
                    case '\b':
                        builder.Append("\\b");
                        break;
                    case '\f':
                        builder.Append("\\f");
                        break;
                    case '\n':
                        builder.Append("\\n");
                        break;
                    case '\r':
                        builder.Append("\\r");
                        break;
                    case '\t':
                        builder.Append("\\t");
                        break;
                    default:
                        if (character < 0x20)
                        {
                            builder.Append("\\u");
                            builder.Append(((int)character).ToString("x4", CultureInfo.InvariantCulture));
                        }
                        else
                        {
                            builder.Append(character);
                        }

                        break;
                }
            }

            builder.Append('"');
        }

        private sealed class Parser
        {
            private readonly string text;
            private int index;

            internal Parser(string text)
            {
                this.text = text;
            }

            internal bool TryParse(out object value, out string error)
            {
                SkipWhitespace();
                if (!TryParseValue(0, out value, out error))
                {
                    return false;
                }

                SkipWhitespace();
                if (index != text.Length)
                {
                    error = ErrorAt("Unexpected trailing content");
                    value = null;
                    return false;
                }

                error = null;
                return true;
            }

            private bool TryParseValue(int depth, out object value, out string error)
            {
                if (depth > MaximumDepth)
                {
                    value = null;
                    error = ErrorAt("JSON nesting exceeds " + MaximumDepth + " levels");
                    return false;
                }

                SkipWhitespace();
                if (index >= text.Length)
                {
                    value = null;
                    error = ErrorAt("Expected a JSON value");
                    return false;
                }

                char token = text[index];
                if (token == '{')
                {
                    return TryParseObject(depth, out value, out error);
                }

                if (token == '[')
                {
                    return TryParseArray(depth, out value, out error);
                }

                if (token == '"')
                {
                    string parsedString;
                    if (TryParseString(out parsedString, out error))
                    {
                        value = parsedString;
                        return true;
                    }

                    value = null;
                    return false;
                }

                if (token == 't' && TryConsumeLiteral("true"))
                {
                    value = true;
                    error = null;
                    return true;
                }

                if (token == 'f' && TryConsumeLiteral("false"))
                {
                    value = false;
                    error = null;
                    return true;
                }

                if (token == 'n' && TryConsumeLiteral("null"))
                {
                    value = null;
                    error = null;
                    return true;
                }

                if (token == '-' || (token >= '0' && token <= '9'))
                {
                    return TryParseNumber(out value, out error);
                }

                value = null;
                error = ErrorAt("Unexpected token '" + token + "'");
                return false;
            }

            private bool TryParseObject(int depth, out object value, out string error)
            {
                var dictionary = new Dictionary<string, object>(StringComparer.Ordinal);
                index++;
                SkipWhitespace();

                if (TryConsume('}'))
                {
                    value = dictionary;
                    error = null;
                    return true;
                }

                while (index < text.Length)
                {
                    string key;
                    if (!TryParseString(out key, out error))
                    {
                        value = null;
                        return false;
                    }

                    if (dictionary.ContainsKey(key))
                    {
                        value = null;
                        error = ErrorAt("Duplicate JSON object key '" + key + "'");
                        return false;
                    }

                    SkipWhitespace();
                    if (!TryConsume(':'))
                    {
                        value = null;
                        error = ErrorAt("Expected ':' after object key");
                        return false;
                    }

                    object item;
                    if (!TryParseValue(depth + 1, out item, out error))
                    {
                        value = null;
                        return false;
                    }

                    dictionary.Add(key, item);
                    SkipWhitespace();
                    if (TryConsume('}'))
                    {
                        value = dictionary;
                        error = null;
                        return true;
                    }

                    if (!TryConsume(','))
                    {
                        value = null;
                        error = ErrorAt("Expected ',' or '}' in object");
                        return false;
                    }

                    SkipWhitespace();
                }

                value = null;
                error = ErrorAt("Unterminated JSON object");
                return false;
            }

            private bool TryParseArray(int depth, out object value, out string error)
            {
                var list = new List<object>();
                index++;
                SkipWhitespace();

                if (TryConsume(']'))
                {
                    value = list;
                    error = null;
                    return true;
                }

                while (index < text.Length)
                {
                    object item;
                    if (!TryParseValue(depth + 1, out item, out error))
                    {
                        value = null;
                        return false;
                    }

                    list.Add(item);
                    SkipWhitespace();
                    if (TryConsume(']'))
                    {
                        value = list;
                        error = null;
                        return true;
                    }

                    if (!TryConsume(','))
                    {
                        value = null;
                        error = ErrorAt("Expected ',' or ']' in array");
                        return false;
                    }

                    SkipWhitespace();
                }

                value = null;
                error = ErrorAt("Unterminated JSON array");
                return false;
            }

            private bool TryParseString(out string value, out string error)
            {
                if (!TryConsume('"'))
                {
                    value = null;
                    error = ErrorAt("Expected a JSON string");
                    return false;
                }

                var builder = new StringBuilder();
                while (index < text.Length)
                {
                    char character = text[index++];
                    if (character == '"')
                    {
                        value = builder.ToString();
                        error = null;
                        return true;
                    }

                    if (character < 0x20)
                    {
                        value = null;
                        error = ErrorAt("Unescaped control character in string");
                        return false;
                    }

                    if (character != '\\')
                    {
                        builder.Append(character);
                        continue;
                    }

                    if (index >= text.Length)
                    {
                        value = null;
                        error = ErrorAt("Unterminated string escape");
                        return false;
                    }

                    char escape = text[index++];
                    switch (escape)
                    {
                        case '"':
                        case '\\':
                        case '/':
                            builder.Append(escape);
                            break;
                        case 'b':
                            builder.Append('\b');
                            break;
                        case 'f':
                            builder.Append('\f');
                            break;
                        case 'n':
                            builder.Append('\n');
                            break;
                        case 'r':
                            builder.Append('\r');
                            break;
                        case 't':
                            builder.Append('\t');
                            break;
                        case 'u':
                            int codePoint;
                            if (!TryParseHex4(out codePoint))
                            {
                                value = null;
                                error = ErrorAt("Invalid Unicode escape");
                                return false;
                            }

                            builder.Append((char)codePoint);
                            break;
                        default:
                            value = null;
                            error = ErrorAt("Invalid string escape '\\" + escape + "'");
                            return false;
                    }
                }

                value = null;
                error = ErrorAt("Unterminated JSON string");
                return false;
            }

            private bool TryParseHex4(out int value)
            {
                value = 0;
                if (index + 4 > text.Length)
                {
                    return false;
                }

                for (int i = 0; i < 4; i++)
                {
                    char character = text[index++];
                    int digit;
                    if (character >= '0' && character <= '9')
                    {
                        digit = character - '0';
                    }
                    else if (character >= 'a' && character <= 'f')
                    {
                        digit = character - 'a' + 10;
                    }
                    else if (character >= 'A' && character <= 'F')
                    {
                        digit = character - 'A' + 10;
                    }
                    else
                    {
                        return false;
                    }

                    value = (value << 4) | digit;
                }

                return true;
            }

            private bool TryParseNumber(out object value, out string error)
            {
                int start = index;
                if (TryConsume('-') && index >= text.Length)
                {
                    value = null;
                    error = ErrorAt("Invalid JSON number");
                    return false;
                }

                if (index < text.Length && text[index] == '0')
                {
                    index++;
                    if (index < text.Length && char.IsDigit(text[index]))
                    {
                        value = null;
                        error = ErrorAt("JSON numbers cannot contain a leading zero");
                        return false;
                    }
                }
                else if (!ConsumeDigits())
                {
                    value = null;
                    error = ErrorAt("Invalid JSON number");
                    return false;
                }

                bool floatingPoint = false;
                if (TryConsume('.'))
                {
                    floatingPoint = true;
                    if (!ConsumeDigits())
                    {
                        value = null;
                        error = ErrorAt("Expected digits after decimal point");
                        return false;
                    }
                }

                if (index < text.Length && (text[index] == 'e' || text[index] == 'E'))
                {
                    floatingPoint = true;
                    index++;
                    if (index < text.Length && (text[index] == '+' || text[index] == '-'))
                    {
                        index++;
                    }

                    if (!ConsumeDigits())
                    {
                        value = null;
                        error = ErrorAt("Expected exponent digits");
                        return false;
                    }
                }

                string token = text.Substring(start, index - start);
                if (!floatingPoint)
                {
                    long integer;
                    if (long.TryParse(token, NumberStyles.Integer, CultureInfo.InvariantCulture, out integer))
                    {
                        value = integer;
                        error = null;
                        return true;
                    }

                    decimal wideInteger;
                    if (decimal.TryParse(token, NumberStyles.Integer, CultureInfo.InvariantCulture, out wideInteger))
                    {
                        value = wideInteger;
                        error = null;
                        return true;
                    }
                }
                else
                {
                    double number;
                    if (double.TryParse(token, NumberStyles.Float, CultureInfo.InvariantCulture, out number) &&
                        !double.IsNaN(number) && !double.IsInfinity(number))
                    {
                        value = number;
                        error = null;
                        return true;
                    }
                }

                value = null;
                error = ErrorAt("JSON number is outside the supported range");
                return false;
            }

            private bool ConsumeDigits()
            {
                int start = index;
                while (index < text.Length && text[index] >= '0' && text[index] <= '9')
                {
                    index++;
                }

                return index > start;
            }

            private bool TryConsumeLiteral(string literal)
            {
                if (index + literal.Length > text.Length)
                {
                    return false;
                }

                for (int i = 0; i < literal.Length; i++)
                {
                    if (text[index + i] != literal[i])
                    {
                        return false;
                    }
                }

                index += literal.Length;
                return true;
            }

            private bool TryConsume(char expected)
            {
                if (index >= text.Length || text[index] != expected)
                {
                    return false;
                }

                index++;
                return true;
            }

            private void SkipWhitespace()
            {
                while (index < text.Length)
                {
                    char character = text[index];
                    if (character != ' ' && character != '\t' && character != '\r' && character != '\n')
                    {
                        return;
                    }

                    index++;
                }
            }

            private string ErrorAt(string message)
            {
                return message + " at character " + index + ".";
            }
        }
    }
}
