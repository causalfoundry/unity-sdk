#if UNITY_IOS
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using UnityEditor.iOS.Xcode.Extensions;
using UnityEngine;

namespace CausalFoundry.Unity.Editor.iOS
{
    /// <summary>Adds the native bridge and the exact iOS Core dependency to generated Xcode projects.</summary>
    internal static class CFIosPostProcess
    {
        private const string RepositoryUrl = "https://github.com/CausalFoundry/ios-sdk";
        private const string PackageVersion = "1.0.10";
        private const string PackageProduct = "KenkaiSDKCore";
        private const string PackageAssetPath =
            "Packages/io.kenkai.upm.sdk/package.json";
        private const string NativeFolder = "Libraries/CausalFoundryUnity";
        private const string LocalPackageFolder = "KenkaiCore";
        private const string LocalPackageProjectPath = NativeFolder + "/" + LocalPackageFolder;
        private const string MmkvXcframeworkProjectPath =
            LocalPackageProjectPath + "/Frameworks/MMKV.xcframework";
        private const string MinimumIosVersion = "13.0";

        private static readonly string[] BackgroundTaskIdentifiers =
        {
            "io.kenkai.ingestAppEvents",
            "io.kenkai.fetchActions"
        };

        [PostProcessBuild(1000)]
        private static void OnPostProcessBuild(BuildTarget target, string buildPath)
        {
            if (target != BuildTarget.iOS)
            {
                return;
            }

            string projectPath = PBXProject.GetPBXProjectPath(buildPath);
            if (!File.Exists(projectPath))
            {
                throw new BuildFailedException(
                    "Causal Foundry could not locate the generated Xcode project at " + projectPath + ".");
            }

            // The wrapper ships its audited Core-only subset as a local package. A remote reference to
            // the same SDK would create a duplicate Swift module and must not be mixed with it.
            string originalProjectText = File.ReadAllText(projectPath);
            PackageReference existingPackage = FindPackageReference(originalProjectText);
            if (existingPackage != null)
            {
                throw PackageConflict();
            }

            string packageRoot = ResolvePackageRoot();
            CopyNativeDirectory(packageRoot, buildPath, LocalPackageFolder);
            string swiftProjectPath = CopyNativeSource(
                packageRoot,
                buildPath,
                "CausalFoundryUnityBridge.swift");
            string bootstrapProjectPath = CopyNativeSource(
                packageRoot,
                buildPath,
                "CausalFoundryUnityEarlyBootstrap.mm");

            var project = new PBXProject();
            project.ReadFromFile(projectPath);
            string frameworkTarget = ResolveUnityFrameworkTarget(project);
            string mainTarget = ResolveUnityMainTarget(project);

            AddSourceToTarget(project, frameworkTarget, swiftProjectPath);
            AddSourceToTarget(project, frameworkTarget, bootstrapProjectPath);
            ConfigureBuildSettings(project, frameworkTarget, mainTarget);
            EmbedMmkv(project, mainTarget);

            project.WriteToFile(projectPath);

            // PBXProject does not expose a portable local Swift-package API across all supported
            // Unity releases. This deterministic text mutation works with Unity 2021.3 and newer.
            string completedProjectText = EnsureLocalSwiftPackageText(
                File.ReadAllText(projectPath),
                frameworkTarget);
            File.WriteAllText(projectPath, completedProjectText, new UTF8Encoding(false));

            UpdateInfoPlist(buildPath);

            Debug.Log(
                "Causal Foundry iOS: linked bundled Core-only " + PackageProduct + " " +
                PackageVersion + " as a local Swift package.");
        }

        private static string ResolvePackageRoot()
        {
            // FindForAssetPath resolves both embedded and PackageCache installations from the
            // package's stable virtual asset path on the Unity 2021.3 baseline and newer.
            UnityEditor.PackageManager.PackageInfo package =
                UnityEditor.PackageManager.PackageInfo.FindForAssetPath(PackageAssetPath);
            if (package != null && Directory.Exists(package.resolvedPath))
            {
                return package.resolvedPath;
            }

            string fallback = Path.GetFullPath(Path.Combine("Packages", "io.kenkai.upm.sdk"));
            if (Directory.Exists(fallback))
            {
                return fallback;
            }
            throw new BuildFailedException("Causal Foundry could not resolve its Unity package directory.");
        }

        private static string CopyNativeSource(string packageRoot, string buildPath, string fileName)
        {
            string source = Path.Combine(
                packageRoot,
                "Runtime",
                "Plugins",
                "iOS",
                "Native~",
                fileName);
            if (!File.Exists(source))
            {
                throw new BuildFailedException("Causal Foundry is missing iOS bridge source " + source + ".");
            }

            string relative = NativeFolder + "/" + fileName;
            string destination = Path.Combine(buildPath, NativeFolder, fileName);
            Directory.CreateDirectory(Path.GetDirectoryName(destination));
            File.Copy(source, destination, true);
            return relative;
        }

        private static void CopyNativeDirectory(
            string packageRoot,
            string buildPath,
            string directoryName)
        {
            string source = Path.Combine(
                packageRoot,
                "Runtime",
                "Plugins",
                "iOS",
                "Native~",
                directoryName);
            if (!Directory.Exists(source))
            {
                throw new BuildFailedException(
                    "Causal Foundry is missing bundled iOS Core package " + source + ".");
            }

            string destination = Path.Combine(buildPath, NativeFolder, directoryName);
            // Replace only this generated dependency directory so incremental Xcode exports cannot
            // retain sources removed from a newer wrapper release.
            if (Directory.Exists(destination))
            {
                Directory.Delete(destination, true);
            }
            CopyDirectory(source, destination);
        }

        private static void CopyDirectory(string source, string destination)
        {
            Directory.CreateDirectory(destination);

            string[] files = Directory.GetFiles(source);
            for (int index = 0; index < files.Length; index++)
            {
                File.Copy(
                    files[index],
                    Path.Combine(destination, Path.GetFileName(files[index])),
                    true);
            }

            string[] directories = Directory.GetDirectories(source);
            for (int index = 0; index < directories.Length; index++)
            {
                CopyDirectory(
                    directories[index],
                    Path.Combine(destination, Path.GetFileName(directories[index])));
            }
        }

        private static void AddSourceToTarget(PBXProject project, string targetGuid, string projectPath)
        {
            string fileGuid = project.FindFileGuidByProjectPath(projectPath);
            if (string.IsNullOrEmpty(fileGuid))
            {
                fileGuid = project.AddFile(projectPath, projectPath, PBXSourceTree.Source);
            }

            // AddFileToBuild is idempotent and also repairs an existing file reference that is
            // not yet a member of this target. Keeping this unconditional avoids relying on
            // PBXProject membership-query APIs that vary across supported Unity releases.
            project.AddFileToBuild(targetGuid, fileGuid);
        }

        private static string ResolveUnityFrameworkTarget(PBXProject project)
        {
            string target = InvokeGuidMethod(project, "GetUnityFrameworkTargetGuid");
            if (string.IsNullOrEmpty(target))
            {
                target = project.TargetGuidByName("UnityFramework");
            }
            if (string.IsNullOrEmpty(target))
            {
                target = ResolveLegacyUnityTarget(project);
            }
            if (string.IsNullOrEmpty(target))
            {
                throw new BuildFailedException(
                    "Causal Foundry could not resolve the UnityFramework target in the Xcode project.");
            }
            return target;
        }

        private static string ResolveUnityMainTarget(PBXProject project)
        {
            string target = InvokeGuidMethod(project, "GetUnityMainTargetGuid");
            if (string.IsNullOrEmpty(target))
            {
                target = ResolveLegacyUnityTarget(project);
            }
            return target;
        }

        private static string ResolveLegacyUnityTarget(PBXProject project)
        {
            MethodInfo method = typeof(PBXProject).GetMethod(
                "GetUnityTargetName",
                BindingFlags.Static | BindingFlags.Public,
                null,
                Type.EmptyTypes,
                null);
            if (method == null)
            {
                return null;
            }
            string name = method.Invoke(null, null) as string;
            return string.IsNullOrEmpty(name) ? null : project.TargetGuidByName(name);
        }

        private static string InvokeGuidMethod(PBXProject project, string methodName)
        {
            MethodInfo method = typeof(PBXProject).GetMethod(
                methodName,
                BindingFlags.Instance | BindingFlags.Public,
                null,
                Type.EmptyTypes,
                null);
            if (method == null)
            {
                return null;
            }
            return method.Invoke(project, null) as string;
        }

        private static void ConfigureBuildSettings(
            PBXProject project,
            string frameworkTarget,
            string mainTarget)
        {
            EnsureMinimumDeploymentTarget(project, frameworkTarget);
            project.SetBuildProperty(frameworkTarget, "SWIFT_VERSION", "5.0");
            project.SetBuildProperty(frameworkTarget, "CLANG_ENABLE_MODULES", "YES");

            if (!string.IsNullOrEmpty(mainTarget))
            {
                EnsureMinimumDeploymentTarget(project, mainTarget);
                project.SetBuildProperty(mainTarget, "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES", "YES");
            }
        }

        private static void EmbedMmkv(PBXProject project, string mainTarget)
        {
            if (string.IsNullOrEmpty(mainTarget))
            {
                throw new BuildFailedException(
                    "Causal Foundry could not resolve the app target needed to embed MMKV.");
            }

            string fileGuid = project.FindFileGuidByProjectPath(MmkvXcframeworkProjectPath);
            if (string.IsNullOrEmpty(fileGuid))
            {
                fileGuid = project.AddFile(
                    MmkvXcframeworkProjectPath,
                    MmkvXcframeworkProjectPath,
                    PBXSourceTree.Source);
            }

            // KenkaiSDKCore is linked from UnityFramework, but iOS only permits dynamic
            // dependencies to be embedded by the application target. Linking and embedding
            // the XCFramework here makes Xcode select the correct device/simulator slice,
            // copy it into the app bundle, and sign it during a signed build.
            project.AddFileToBuild(mainTarget, fileGuid);
            PBXProjectExtensions.AddFileToEmbedFrameworks(project, mainTarget, fileGuid);
        }

        private static void EnsureMinimumDeploymentTarget(PBXProject project, string targetGuid)
        {
            string existing = null;
            MethodInfo getter = typeof(PBXProject).GetMethod(
                "GetBuildPropertyForAnyConfig",
                BindingFlags.Instance | BindingFlags.Public,
                null,
                new[] { typeof(string), typeof(string) },
                null);
            if (getter != null)
            {
                existing = getter.Invoke(
                    project,
                    new object[] { targetGuid, "IPHONEOS_DEPLOYMENT_TARGET" }) as string;
            }

            Version parsed;
            if (!string.IsNullOrEmpty(existing) && Version.TryParse(existing, out parsed) &&
                parsed >= new Version(13, 0))
            {
                return;
            }
            project.SetBuildProperty(targetGuid, "IPHONEOS_DEPLOYMENT_TARGET", MinimumIosVersion);
        }

        private static void UpdateInfoPlist(string buildPath)
        {
            string plistPath = Path.Combine(buildPath, "Info.plist");
            if (!File.Exists(plistPath))
            {
                throw new BuildFailedException("Causal Foundry could not locate the generated Info.plist.");
            }

            var plist = new PlistDocument();
            plist.ReadFromFile(plistPath);
            EnsureStringArray(plist.root, "BGTaskSchedulerPermittedIdentifiers", BackgroundTaskIdentifiers);
            EnsureStringArray(plist.root, "UIBackgroundModes", new[] { "fetch", "processing" });

            CFSettings settings = CFSettings.LoadFromResources();
            bool autoInitialize = settings != null &&
                settings.AutoInitialize &&
                !IsBlank(settings.SdkKey);

            plist.root.SetBoolean("CausalFoundryUnityAutoInitialize", autoInitialize);
            plist.root.SetString(
                "CausalFoundryUnitySDKKey",
                autoInitialize ? settings.SdkKey.Trim() : string.Empty);
            plist.root.SetString(
                "CausalFoundryUnityOptionsJSON",
                autoInitialize ? SerializeOptions(settings) : "{}");
            plist.WriteToFile(plistPath);

            if (!autoInitialize)
            {
                Debug.LogWarning(
                    "Causal Foundry iOS early lifecycle bootstrap has no SDK key. Add an " +
                    "Assets/Resources/CausalFoundrySettings.asset with Auto Initialize enabled " +
                    "to capture the first app-open event; runtime Initialize remains available.");
            }
        }

        private static void EnsureStringArray(
            PlistElementDict root,
            string key,
            string[] requiredValues)
        {
            PlistElement existing;
            PlistElementArray array;
            if (root.values.TryGetValue(key, out existing))
            {
                array = existing as PlistElementArray;
                if (array == null)
                {
                    throw new BuildFailedException(
                        "Causal Foundry requires Info.plist key '" + key + "' to be an array.");
                }
            }
            else
            {
                array = root.CreateArray(key);
            }

            var values = new HashSet<string>(StringComparer.Ordinal);
            for (int index = 0; index < array.values.Count; index++)
            {
                PlistElementString value = array.values[index] as PlistElementString;
                if (value != null)
                {
                    values.Add(value.value);
                }
            }
            for (int index = 0; index < requiredValues.Length; index++)
            {
                if (values.Add(requiredValues[index]))
                {
                    array.AddString(requiredValues[index]);
                }
            }
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

        private static bool IsBlank(string value)
        {
            return string.IsNullOrEmpty(value) || value.Trim().Length == 0;
        }

        private sealed class PackageReference
        {
            internal string Guid;
        }

        private sealed class LocalPackageReference
        {
            internal string Guid;
        }

        private static PackageReference FindPackageReference(string source)
        {
            var expression = new Regex(
                @"^[ \t]*(?<guid>[A-Fa-f0-9]{24})(?:[ \t]+/\*[^\r\n]*\*/)?" +
                @"[ \t]*=[ \t]*\{\s*" +
                @"isa\s*=\s*XCRemoteSwiftPackageReference\s*;\s*" +
                @"repositoryURL\s*=\s*(?<url>[^;]+);(?<body>[\s\S]*?)(?:^[ \t]*\};)",
                RegexOptions.Multiline | RegexOptions.CultureInvariant);

            PackageReference result = null;
            MatchCollection matches = expression.Matches(source);
            for (int index = 0; index < matches.Count; index++)
            {
                string url = matches[index].Groups["url"].Value.Trim().Trim('"');
                if (!SameRepository(url, RepositoryUrl))
                {
                    continue;
                }
                if (result != null)
                {
                    throw new BuildFailedException(
                        "Causal Foundry found duplicate Swift package references for " +
                        RepositoryUrl + ". Remove the duplicate before building.");
                }
                result = new PackageReference
                {
                    Guid = matches[index].Groups["guid"].Value.ToUpperInvariant()
                };
            }
            return result;
        }

        private static LocalPackageReference FindLocalPackageReference(string source)
        {
            var expression = new Regex(
                @"^[ \t]*(?<guid>[A-Fa-f0-9]{24})(?:[ \t]+/\*[^\r\n]*\*/)?" +
                @"[ \t]*=[ \t]*\{\s*" +
                @"isa\s*=\s*XCLocalSwiftPackageReference\s*;\s*" +
                @"relativePath\s*=\s*(?<path>[^;]+);[\s\S]*?(?:^[ \t]*\};)",
                RegexOptions.Multiline | RegexOptions.CultureInvariant);

            LocalPackageReference result = null;
            MatchCollection matches = expression.Matches(source);
            for (int index = 0; index < matches.Count; index++)
            {
                string path = NormalizeProjectPath(matches[index].Groups["path"].Value);
                if (!string.Equals(
                        path,
                        NormalizeProjectPath(LocalPackageProjectPath),
                        StringComparison.Ordinal))
                {
                    continue;
                }
                if (result != null)
                {
                    throw new BuildFailedException(
                        "Causal Foundry found duplicate local Swift package references for " +
                        LocalPackageProjectPath + ". Remove the duplicate before building.");
                }
                result = new LocalPackageReference
                {
                    Guid = matches[index].Groups["guid"].Value.ToUpperInvariant()
                };
            }
            return result;
        }

        private static bool SameRepository(string left, string right)
        {
            return string.Equals(NormalizeRepository(left), NormalizeRepository(right),
                StringComparison.OrdinalIgnoreCase);
        }

        private static string NormalizeRepository(string value)
        {
            string result = value.Trim().TrimEnd('/');
            if (result.EndsWith(".git", StringComparison.OrdinalIgnoreCase))
            {
                result = result.Substring(0, result.Length - 4);
            }
            return result;
        }

        private static string NormalizeProjectPath(string value)
        {
            return value.Trim().Trim('"').Replace('\\', '/').Trim('/');
        }

        private static BuildFailedException PackageConflict()
        {
            return new BuildFailedException(
                "Causal Foundry Unity bundles the iOS Core package at exact version " +
                PackageVersion + ", but the generated Xcode project already references " +
                RepositoryUrl + ". Remove that remote package reference to avoid linking two " +
                "copies of " + PackageProduct + ".");
        }

        private static string EnsureLocalSwiftPackageText(string source, string frameworkTargetGuid)
        {
            if (FindPackageReference(source) != null)
            {
                throw PackageConflict();
            }

            LocalPackageReference package = FindLocalPackageReference(source);
            if (package == null)
            {
                package = new LocalPackageReference
                {
                    Guid = CreateUnusedGuid(source, "CausalFoundry.Package"),
                };
                string packageEntry =
                    "\t\t" + package.Guid + " /* XCLocalSwiftPackageReference \"" +
                    LocalPackageFolder + "\" */ = {\n" +
                    "\t\t\tisa = XCLocalSwiftPackageReference;\n" +
                    "\t\t\trelativePath = " + LocalPackageProjectPath + ";\n" +
                    "\t\t};\n";
                source = InsertSectionEntry(
                    source,
                    "XCLocalSwiftPackageReference",
                    packageEntry);
            }

            string productGuid = FindProductDependencyGuid(source, package.Guid);
            if (string.IsNullOrEmpty(productGuid))
            {
                productGuid = CreateUnusedGuid(source, "CausalFoundry.Product");
                string productEntry =
                    "\t\t" + productGuid + " /* " + PackageProduct + " */ = {\n" +
                    "\t\t\tisa = XCSwiftPackageProductDependency;\n" +
                    "\t\t\tpackage = " + package.Guid +
                    " /* XCLocalSwiftPackageReference \"" + LocalPackageFolder + "\" */;\n" +
                    "\t\t\tproductName = " + PackageProduct + ";\n" +
                    "\t\t};\n";
                source = InsertSectionEntry(
                    source,
                    "XCSwiftPackageProductDependency",
                    productEntry);
            }

            string buildFileGuid = FindProductBuildFileGuid(source, productGuid);
            if (string.IsNullOrEmpty(buildFileGuid))
            {
                buildFileGuid = CreateUnusedGuid(source, "CausalFoundry.BuildFile");
                string buildEntry =
                    "\t\t" + buildFileGuid + " /* " + PackageProduct + " in Frameworks */ = " +
                    "{isa = PBXBuildFile; productRef = " + productGuid +
                    " /* " + PackageProduct + " */; };\n";
                source = InsertSectionEntry(source, "PBXBuildFile", buildEntry);
            }

            Match rootMatch = Regex.Match(
                source,
                @"\brootObject\s*=\s*(?<guid>[A-Fa-f0-9]{24})\b",
                RegexOptions.CultureInvariant);
            if (!rootMatch.Success)
            {
                throw TextFallbackFailure("could not resolve the PBXProject root object");
            }

            source = AddGuidToObjectList(
                source,
                rootMatch.Groups["guid"].Value,
                "packageReferences",
                package.Guid + " /* XCLocalSwiftPackageReference \"" +
                LocalPackageFolder + "\" */,");
            source = AddGuidToObjectList(
                source,
                frameworkTargetGuid,
                "packageProductDependencies",
                productGuid + " /* " + PackageProduct + " */,");

            string frameworksPhaseGuid = FindFrameworksPhaseGuid(source, frameworkTargetGuid);
            source = AddGuidToObjectList(
                source,
                frameworksPhaseGuid,
                "files",
                buildFileGuid + " /* " + PackageProduct + " in Frameworks */,");

            LocalPackageReference finalReference = FindLocalPackageReference(source);
            if (finalReference == null ||
                source.IndexOf("productName = " + PackageProduct + ";", StringComparison.Ordinal) < 0)
            {
                throw TextFallbackFailure("could not verify the completed local Swift package graph");
            }
            return source;
        }

        private static string FindProductDependencyGuid(string source, string packageGuid)
        {
            string marker = "productName = " + PackageProduct + ";";
            int searchIndex = 0;
            while (searchIndex < source.Length)
            {
                int productIndex = source.IndexOf(marker, searchIndex, StringComparison.Ordinal);
                if (productIndex < 0)
                {
                    return null;
                }

                int objectAssignment = source.LastIndexOf(" = {", productIndex,
                    StringComparison.Ordinal);
                int lineStart = objectAssignment < 0
                    ? -1
                    : source.LastIndexOf('\n', objectAssignment) + 1;
                string header = lineStart < 0
                    ? string.Empty
                    : source.Substring(lineStart, objectAssignment - lineStart);
                Match guidMatch = Regex.Match(
                    header,
                    @"\b(?<guid>[A-Fa-f0-9]{24})\b",
                    RegexOptions.CultureInvariant);
                string guid = guidMatch.Success ? guidMatch.Groups["guid"].Value : null;
                string body = guid == null ? null : GetObjectBlock(source, guid, false);
                if (Regex.IsMatch(
                        body ?? string.Empty,
                        @"\bisa\s*=\s*XCSwiftPackageProductDependency\s*;",
                        RegexOptions.CultureInvariant) &&
                    Regex.IsMatch(
                        body ?? string.Empty,
                        @"\bpackage\s*=\s*" + Regex.Escape(packageGuid) + @"\b",
                        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
                {
                    return guid.ToUpperInvariant();
                }
                searchIndex = productIndex + marker.Length;
            }
            return null;
        }

        private static string FindProductBuildFileGuid(string source, string productGuid)
        {
            Match match = Regex.Match(
                source,
                @"(?m)^[ \t]*(?<guid>[A-Fa-f0-9]{24})(?:[ \t]+/\*[^\r\n]*\*/)?" +
                @"[ \t]*=[ \t]*\{" +
                @"[^\r\n]*\bisa\s*=\s*PBXBuildFile\s*;[^\r\n]*\bproductRef\s*=\s*" +
                Regex.Escape(productGuid) + @"\b",
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
            return match.Success ? match.Groups["guid"].Value.ToUpperInvariant() : null;
        }

        private static string FindFrameworksPhaseGuid(string source, string targetGuid)
        {
            string targetBlock = GetObjectBlock(source, targetGuid);
            Match phaseList = Regex.Match(
                targetBlock,
                @"(?ms)\bbuildPhases\s*=\s*\((?<values>.*?)\);",
                RegexOptions.CultureInvariant);
            if (!phaseList.Success)
            {
                throw TextFallbackFailure("could not resolve UnityFramework build phases");
            }

            MatchCollection guids = Regex.Matches(
                phaseList.Groups["values"].Value,
                @"\b[A-Fa-f0-9]{24}\b",
                RegexOptions.CultureInvariant);
            for (int index = 0; index < guids.Count; index++)
            {
                string guid = guids[index].Value;
                string block = GetObjectBlock(source, guid, false);
                if (block != null && Regex.IsMatch(
                        block,
                        @"\bisa\s*=\s*PBXFrameworksBuildPhase\s*;",
                        RegexOptions.CultureInvariant))
                {
                    return guid.ToUpperInvariant();
                }
            }
            throw TextFallbackFailure("could not resolve the UnityFramework Frameworks phase");
        }

        private static string InsertSectionEntry(string source, string section, string entry)
        {
            string begin = "/* Begin " + section + " section */";
            string end = "/* End " + section + " section */";
            int endIndex = source.IndexOf(end, StringComparison.Ordinal);
            if (endIndex >= 0)
            {
                int lineStart = source.LastIndexOf('\n', endIndex) + 1;
                return source.Insert(lineStart, entry);
            }

            int insertion = source.IndexOf(
                "/* Begin PBXProject section */",
                StringComparison.Ordinal);
            if (insertion < 0)
            {
                throw TextFallbackFailure("could not locate a section insertion point for " + section);
            }
            insertion = source.LastIndexOf('\n', insertion) + 1;
            string newSection = begin + "\n" + entry + end + "\n\n";
            return source.Insert(insertion, newSection);
        }

        private static string AddGuidToObjectList(
            string source,
            string objectGuid,
            string property,
            string entry)
        {
            ObjectBlock objectBlock = GetObjectBlockRange(source, objectGuid);
            string block = source.Substring(objectBlock.Start, objectBlock.Length);
            var propertyExpression = new Regex(
                @"(?m)^(?<indent>[ \t]*)" + Regex.Escape(property) + @"\s*=\s*\(\r?$",
                RegexOptions.CultureInvariant);
            Match propertyMatch = propertyExpression.Match(block);

            if (propertyMatch.Success)
            {
                string indent = propertyMatch.Groups["indent"].Value;
                int listEnd = block.IndexOf("\n" + indent + ");", propertyMatch.Index,
                    StringComparison.Ordinal);
                if (listEnd < 0)
                {
                    throw TextFallbackFailure("found a malformed " + property + " list");
                }
                string list = block.Substring(propertyMatch.Index, listEnd - propertyMatch.Index);
                string guid = Regex.Match(entry, @"[A-Fa-f0-9]{24}").Value;
                if (Regex.IsMatch(list, @"\b" + Regex.Escape(guid) + @"\b",
                        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
                {
                    return source;
                }

                int openingLineEnd = block.IndexOf('\n', propertyMatch.Index);
                if (openingLineEnd < 0)
                {
                    throw TextFallbackFailure("found a malformed " + property + " opening line");
                }
                block = block.Insert(openingLineEnd + 1, indent + "\t" + entry + "\n");
            }
            else
            {
                int closing = block.LastIndexOf("\n", StringComparison.Ordinal);
                if (closing < 0)
                {
                    throw TextFallbackFailure("found a malformed object for " + property);
                }
                string objectIndent = LeadingWhitespace(block);
                string indent = objectIndent + "\t";
                string list =
                    indent + property + " = (\n" +
                    indent + "\t" + entry + "\n" +
                    indent + ");\n";
                block = block.Insert(closing + 1, list);
            }

            return source.Substring(0, objectBlock.Start) + block +
                source.Substring(objectBlock.Start + objectBlock.Length);
        }

        private sealed class ObjectBlock
        {
            internal int Start;
            internal int Length;
        }

        private static string GetObjectBlock(string source, string guid)
        {
            return GetObjectBlock(source, guid, true);
        }

        private static string GetObjectBlock(string source, string guid, bool required)
        {
            try
            {
                ObjectBlock range = GetObjectBlockRange(source, guid);
                return source.Substring(range.Start, range.Length);
            }
            catch (BuildFailedException)
            {
                if (!required)
                {
                    return null;
                }
                throw;
            }
        }

        private static ObjectBlock GetObjectBlockRange(string source, string guid)
        {
            Match match = Regex.Match(
                source,
                @"(?m)^[ \t]*" + Regex.Escape(guid) +
                @"(?:[ \t]+/\*[^\r\n]*\*/)?[ \t]*=[ \t]*\{",
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
            if (!match.Success)
            {
                throw TextFallbackFailure("could not find PBX object " + guid);
            }

            int openingBrace = source.IndexOf('{', match.Index);
            int depth = 0;
            for (int index = openingBrace; index < source.Length; index++)
            {
                if (source[index] == '{')
                {
                    depth++;
                }
                else if (source[index] == '}')
                {
                    depth--;
                    if (depth == 0)
                    {
                        int end = index + 1;
                        if (end < source.Length && source[end] == ';')
                        {
                            end++;
                        }
                        return new ObjectBlock { Start = match.Index, Length = end - match.Index };
                    }
                }
            }
            throw TextFallbackFailure("found an unterminated PBX object " + guid);
        }

        private static string LeadingWhitespace(string value)
        {
            int length = 0;
            while (length < value.Length && (value[length] == ' ' || value[length] == '\t'))
            {
                length++;
            }
            return value.Substring(0, length);
        }

        private static string CreateUnusedGuid(string source, string seed)
        {
            for (int attempt = 0; attempt < 100; attempt++)
            {
                string value;
                using (MD5 hash = MD5.Create())
                {
                    byte[] bytes = hash.ComputeHash(
                        Encoding.UTF8.GetBytes(seed + "." + attempt.ToString(CultureInfo.InvariantCulture)));
                    var builder = new StringBuilder(24);
                    for (int index = 0; index < 12; index++)
                    {
                        builder.Append(bytes[index].ToString("X2", CultureInfo.InvariantCulture));
                    }
                    value = builder.ToString();
                }
                if (!Regex.IsMatch(source, @"\b" + value + @"\b",
                        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
                {
                    return value;
                }
            }
            throw TextFallbackFailure("could not allocate a unique PBX object identifier");
        }

        private static BuildFailedException TextFallbackFailure(string reason)
        {
            return new BuildFailedException(
                "Causal Foundry could not safely update this generated Xcode project because it " +
                reason + ". Use a standard Unity-generated Xcode project.");
        }
    }
}
#endif
