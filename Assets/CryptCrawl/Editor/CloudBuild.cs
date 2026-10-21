using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace CryptCrawl.EditorTools
{
    /// <summary>
    /// Entry point for the GitHub cloud build (.github/workflows/android-build.yml).
    /// Prepares the project exactly like opening it in Unity would, links any KayKit art
    /// that was uploaded, then builds an Android .apk you can install on your phone.
    /// </summary>
    public static class CloudBuild
    {
        public static void BuildAndroid()
        {
            int code = 1;
            try
            {
                ProjectSetup.EnsureMaterials();
                ProjectSetup.EnsureScene(openIfIdle: false);
                ProjectSetup.ApplyPlayerSettings();
                if (AssetDatabase.IsValidFolder("Assets/KayKit")) KayKitLinker.Link();

                string output = Arg("-customBuildPath") ?? "build/Android/CryptCrawl.apk";
                if (!output.EndsWith(".apk", StringComparison.OrdinalIgnoreCase)) output = Path.Combine(output, "CryptCrawl.apk");
                Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output)));

                string version = Arg("-buildVersion");
                if (!string.IsNullOrEmpty(version)) PlayerSettings.bundleVersion = version;
                string versionCode = Arg("-androidVersionCode");
                if (int.TryParse(versionCode, out int vc) && vc > 0) PlayerSettings.Android.bundleVersionCode = vc;

                EditorUserBuildSettings.buildAppBundle = false;
                var options = new BuildPlayerOptions
                {
                    scenes = new[] { ProjectSetup.ScenePath },
                    locationPathName = output,
                    target = BuildTarget.Android,
                    options = BuildOptions.None,
                };
                var report = BuildPipeline.BuildPlayer(options);
                Debug.Log($"[Crypt Crawl] Build {report.summary.result}: {output} ({report.summary.totalSize / (1024 * 1024)} MB)");
                code = report.summary.result == BuildResult.Succeeded ? 0 : 1;
            }
            catch (Exception e)
            {
                Debug.LogException(e);
                code = 1;
            }
            EditorApplication.Exit(code);
        }

        static string Arg(string name)
        {
            var args = Environment.GetCommandLineArgs();
            int i = Array.IndexOf(args, name);
            return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
        }
    }
}
