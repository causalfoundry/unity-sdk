using System.Collections.Generic;
using CausalFoundry.Unity.Internal;
using NUnit.Framework;

namespace CausalFoundry.Unity.Editor.Tests
{
    public sealed class CFJsonTests
    {
        [Test]
        public void Serialize_SortsObjectKeysAndUsesInvariantJson()
        {
            var input = new Dictionary<string, object>
            {
                { "z", 3.5d },
                { "a", new List<object> { true, null, "line\nbreak" } },
                { "m", -7L }
            };

            string json;
            string error;
            bool success = CFJson.TrySerialize(input, out json, out error);

            Assert.That(success, Is.True, error);
            Assert.That(json, Is.EqualTo("{\"a\":[true,null,\"line\\nbreak\"],\"m\":-7,\"z\":3.5}"));
        }

        [Test]
        public void Serialize_AcceptsGenericDictionaryImplementations()
        {
            IDictionary<string, object> input = new SortedDictionary<string, object>
            {
                { "b", 2L },
                { "a", 1L }
            };

            string json;
            string error;

            Assert.That(CFJson.TrySerialize(input, out json, out error), Is.True, error);
            Assert.That(json, Is.EqualTo("{\"a\":1,\"b\":2}"));
        }

        [Test]
        public void Deserialize_RoundTripsNestedPrimitivesAndEscapes()
        {
            const string source = "{\"emoji\":\"\\u263a\",\"items\":[1,-2.25,false],\"nested\":{\"x\":null}}";

            object parsed;
            string error;
            Assert.That(CFJson.TryDeserialize(source, out parsed, out error), Is.True, error);

            string encoded;
            Assert.That(CFJson.TrySerialize(parsed, out encoded, out error), Is.True, error);
            Assert.That(encoded, Is.EqualTo("{\"emoji\":\"☺\",\"items\":[1,-2.25,false],\"nested\":{\"x\":null}}"));
        }

        [TestCase("{\"a\":1,}")]
        [TestCase("[1 2]")]
        [TestCase("01")]
        [TestCase("{\"a\":1,\"a\":2}")]
        public void Deserialize_RejectsMalformedJson(string source)
        {
            object parsed;
            string error;

            Assert.That(CFJson.TryDeserialize(source, out parsed, out error), Is.False);
            Assert.That(error, Is.Not.Empty);
        }

        [Test]
        public void Serialize_RejectsUnsupportedObjectsAndNonFiniteNumbers()
        {
            string json;
            string error;

            Assert.That(CFJson.TrySerialize(new object(), out json, out error), Is.False);
            Assert.That(error, Does.Contain("Unsupported"));
            Assert.That(CFJson.TrySerialize(double.NaN, out json, out error), Is.False);
            Assert.That(error, Does.Contain("NaN"));
        }
    }
}
