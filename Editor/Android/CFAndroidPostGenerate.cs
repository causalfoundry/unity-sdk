#if UNITY_ANDROID
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using UnityEditor.Android;
using UnityEditor.Build;
using UnityEngine;

namespace CausalFoundry.Unity.Editor.Android
{
    /// <summary>
    /// Adds the Core SDK's Maven graph after Unity generates the Gradle project. This deliberately
    /// avoids EDM4U and works with both exported projects and direct Unity Gradle builds.
    /// </summary>
    public sealed class CFAndroidPostGenerate : IPostGenerateGradleAndroidProject
    {
        private const string DependencyMarkerBegin =
            "// <causal-foundry-unity-dependencies>";
        private const string DependencyMarkerEnd =
            "// </causal-foundry-unity-dependencies>";
        private const string PropertiesMarkerBegin =
            "# <causal-foundry-unity-properties>";
        private const string PropertiesMarkerEnd =
            "# </causal-foundry-unity-properties>";
        private const string AndroidNamespace = "http://schemas.android.com/apk/res/android";
        private const int RequiredCompileSdk = 33;

        public int callbackOrder
        {
            get { return 1000; }
        }

        public void OnPostGenerateGradleAndroidProject(string path)
        {
            string projectRoot = ResolveProjectRoot(path);
            string moduleGradle = FindUnityLibraryGradle(path, projectRoot);
            InjectGradleProperties(projectRoot);
            InjectDependencies(moduleGradle, projectRoot);
            ValidateCompileSdk(moduleGradle, projectRoot);
            InjectEarlyLifecycleConfiguration(path, projectRoot);
        }

        private static void InjectGradleProperties(string projectRoot)
        {
            string propertiesPath = Path.Combine(projectRoot, "gradle.properties");
            string source = File.Exists(propertiesPath)
                ? File.ReadAllText(propertiesPath)
                : string.Empty;
            string block = PropertiesMarkerBegin + Environment.NewLine +
                "android.useAndroidX=true" + Environment.NewLine +
                "android.enableJetifier=true" + Environment.NewLine +
                PropertiesMarkerEnd;
            source = ReplaceOrAppendMarkedBlock(
                source,
                PropertiesMarkerBegin,
                PropertiesMarkerEnd,
                block);
            File.WriteAllText(propertiesPath, source, new UTF8Encoding(false));
        }

        private static void InjectDependencies(string moduleGradle, string projectRoot)
        {
            string source = File.ReadAllText(moduleGradle);
            bool kotlinDsl = moduleGradle.EndsWith(".kts", StringComparison.OrdinalIgnoreCase);
            bool hasMavenCentral = ProjectContains(projectRoot, "mavenCentral");

            var block = new StringBuilder();
            block.AppendLine(DependencyMarkerBegin);
            if (!hasMavenCentral)
            {
                // Some supported Unity exports use project repositories. Newer Unity versions
                // declare repositories in settings.gradle and therefore do not enter this branch.
                block.AppendLine("repositories {");
                block.AppendLine("    mavenCentral()");
                block.AppendLine("}");
                block.AppendLine();
            }
            block.AppendLine("dependencies {");
            if (kotlinDsl)
            {
                block.AppendLine("    implementation(\"io.kenkai.android.sdk:core:1.0.10\")");
                block.AppendLine("    implementation(\"androidx.lifecycle:lifecycle-process:2.5.1\")");
                block.AppendLine("    implementation(\"androidx.startup:startup-runtime:1.1.1\")");
            }
            else
            {
                block.AppendLine("    implementation 'io.kenkai.android.sdk:core:1.0.10'");
                block.AppendLine("    implementation 'androidx.lifecycle:lifecycle-process:2.5.1'");
                block.AppendLine("    implementation 'androidx.startup:startup-runtime:1.1.1'");
            }
            block.AppendLine("}");
            block.Append(DependencyMarkerEnd);

            source = ReplaceOrAppendMarkedBlock(
                source,
                DependencyMarkerBegin,
                DependencyMarkerEnd,
                block.ToString());
            File.WriteAllText(moduleGradle, source, new UTF8Encoding(false));
        }

        private static void ValidateCompileSdk(string moduleGradle, string projectRoot)
        {
            var expression = new Regex(
                @"\bcompileSdk(?:Version)?\s*(?:=\s*)?(\d+)",
                RegexOptions.CultureInvariant);
            var discovered = FindCompileSdkValues(moduleGradle, expression);

            // If the unityLibrary module references a root property instead of a literal, inspect
            // only root Gradle files. Unrelated plugin submodules may legitimately compile against
            // an older SDK and do not host the Core dependency injected above.
            if (discovered.Count == 0)
            {
                string[] rootGradleFiles = Directory.GetFiles(
                    projectRoot,
                    "*.gradle*",
                    SearchOption.TopDirectoryOnly);
                for (int fileIndex = 0; fileIndex < rootGradleFiles.Length; fileIndex++)
                {
                    discovered.AddRange(
                        FindCompileSdkValues(rootGradleFiles[fileIndex], expression));
                }
            }

            for (int index = 0; index < discovered.Count; index++)
            {
                if (discovered[index] < RequiredCompileSdk)
                {
                    throw new BuildFailedException(
                        "Causal Foundry Android Core 1.0.10 requires compileSdk " +
                        RequiredCompileSdk + " or newer. Generated unityLibrary uses " +
                        discovered[index] + ".");
                }
            }

            if (discovered.Count == 0)
            {
                Debug.LogWarning(
                    "Causal Foundry could not resolve a numeric unityLibrary compileSdk from the " +
                    "generated Gradle files. Android Core 1.0.10 requires compileSdk 33 or newer.");
            }
        }

        private static List<int> FindCompileSdkValues(string file, Regex expression)
        {
            var discovered = new List<int>();
            MatchCollection matches = expression.Matches(File.ReadAllText(file));
            for (int matchIndex = 0; matchIndex < matches.Count; matchIndex++)
            {
                int value;
                if (int.TryParse(
                        matches[matchIndex].Groups[1].Value,
                        NumberStyles.None,
                        CultureInfo.InvariantCulture,
                        out value))
                {
                    discovered.Add(value);
                }
            }
            return discovered;
        }

        private static void InjectEarlyLifecycleConfiguration(string callbackPath, string projectRoot)
        {
            CFSettings settings = CFSettings.LoadFromResources();
            if (settings == null || !settings.AutoInitialize || IsBlank(settings.SdkKey))
            {
                Debug.LogWarning(
                    "Causal Foundry Android early lifecycle bootstrap has no SDK key. Add an " +
                    "Assets/Resources/CausalFoundrySettings.asset with Auto Initialize enabled " +
                    "to capture the first app-open lifecycle; runtime Initialize remains available.");
                return;
            }

            string manifestPath = FindUnityLibraryManifest(callbackPath, projectRoot);
            var document = new XmlDocument();
            document.PreserveWhitespace = true;
            document.Load(manifestPath);

            XmlElement manifest = document.DocumentElement;
            if (manifest == null)
            {
                throw new BuildFailedException(
                    "Causal Foundry could not read the generated Android manifest.");
            }

            XmlElement application = null;
            for (int index = 0; index < manifest.ChildNodes.Count; index++)
            {
                XmlElement element = manifest.ChildNodes[index] as XmlElement;
                if (element != null && element.LocalName == "application")
                {
                    application = element;
                    break;
                }
            }
            if (application == null)
            {
                application = document.CreateElement("application");
                manifest.AppendChild(application);
            }

            SetMetadata(
                document,
                application,
                "ai.causalfoundry.unity.SDK_KEY",
                settings.SdkKey.Trim());
            SetMetadata(
                document,
                application,
                "io.kenkai.android.sdk.APPLICATION_KEY",
                settings.SdkKey.Trim());
            SetMetadata(
                document,
                application,
                "ai.causalfoundry.unity.OPTIONS_JSON",
                SerializeOptions(settings));

            document.Save(manifestPath);
        }

        private static void SetMetadata(
            XmlDocument document,
            XmlElement application,
            string name,
            string value)
        {
            XmlElement target = null;
            for (int index = 0; index < application.ChildNodes.Count; index++)
            {
                XmlElement element = application.ChildNodes[index] as XmlElement;
                if (element != null
                    && element.LocalName == "meta-data"
                    && element.GetAttribute("name", AndroidNamespace) == name)
                {
                    target = element;
                    break;
                }
            }
            if (target == null)
            {
                target = document.CreateElement("meta-data");
                application.AppendChild(target);
            }
            target.SetAttribute("name", AndroidNamespace, name);
            target.SetAttribute("value", AndroidNamespace, value);
        }

        private static string SerializeOptions(CFSettings settings)
        {
            return "{" +
                "\"allow_anonymous_users\":" + JsonBoolean(settings.AllowAnonymousUsers) + "," +
                "\"auto_show_in_app_messages\":" + JsonBoolean(settings.AutoShowInAppMessages) + "," +
                "\"auto_track_pages\":" + JsonBoolean(!settings.DisableAutoPageTracking) + "," +
                "\"disable_auto_page_tracking\":" + JsonBoolean(settings.DisableAutoPageTracking) + "," +
                "\"enable_debug_mode\":" + JsonBoolean(settings.EnableDebugMode) + "," +
                "\"pause_sdk\":" + JsonBoolean(settings.PauseSdk) + "," +
                "\"update_immediately\":" + JsonBoolean(settings.UpdateImmediately) +
                "}";
        }

        private static string JsonBoolean(bool value)
        {
            return value ? "true" : "false";
        }

        private static string ReplaceOrAppendMarkedBlock(
            string source,
            string begin,
            string end,
            string replacement)
        {
            int beginIndex = source.IndexOf(begin, StringComparison.Ordinal);
            if (beginIndex >= 0)
            {
                int endIndex = source.IndexOf(end, beginIndex, StringComparison.Ordinal);
                if (endIndex < 0)
                {
                    throw new BuildFailedException(
                        "Causal Foundry found a malformed Gradle marker block in the generated project.");
                }
                endIndex += end.Length;
                return source.Substring(0, beginIndex) + replacement + source.Substring(endIndex);
            }

            string newline = source.EndsWith("\n", StringComparison.Ordinal) ? "" : Environment.NewLine;
            return source + newline + Environment.NewLine + replacement + Environment.NewLine;
        }

        private static bool ProjectContains(string projectRoot, string value)
        {
            string[] candidates = Directory.GetFiles(
                projectRoot,
                "*.gradle*",
                SearchOption.TopDirectoryOnly);
            for (int index = 0; index < candidates.Length; index++)
            {
                if (File.ReadAllText(candidates[index]).IndexOf(value, StringComparison.Ordinal) >= 0)
                {
                    return true;
                }
            }
            return false;
        }

        private static string ResolveProjectRoot(string path)
        {
            DirectoryInfo directory = new DirectoryInfo(path);
            if (string.Equals(directory.Name, "unityLibrary", StringComparison.OrdinalIgnoreCase)
                && directory.Parent != null)
            {
                return directory.Parent.FullName;
            }
            return directory.FullName;
        }

        private static string FindUnityLibraryGradle(string callbackPath, string projectRoot)
        {
            string[] candidates =
            {
                Path.Combine(projectRoot, "unityLibrary", "build.gradle"),
                Path.Combine(projectRoot, "unityLibrary", "build.gradle.kts"),
                Path.Combine(callbackPath, "build.gradle"),
                Path.Combine(callbackPath, "build.gradle.kts")
            };
            return FirstExisting(candidates, "Unity library Gradle file");
        }

        private static string FindUnityLibraryManifest(string callbackPath, string projectRoot)
        {
            string[] candidates =
            {
                Path.Combine(projectRoot, "unityLibrary", "src", "main", "AndroidManifest.xml"),
                Path.Combine(callbackPath, "src", "main", "AndroidManifest.xml")
            };
            return FirstExisting(candidates, "Unity library AndroidManifest.xml");
        }

        private static string FirstExisting(string[] candidates, string label)
        {
            for (int index = 0; index < candidates.Length; index++)
            {
                if (File.Exists(candidates[index]))
                {
                    return candidates[index];
                }
            }
            throw new BuildFailedException(
                "Causal Foundry could not locate the generated " + label + ".");
        }

        private static bool IsBlank(string value)
        {
            return string.IsNullOrEmpty(value) || value.Trim().Length == 0;
        }
    }
}
#endif
