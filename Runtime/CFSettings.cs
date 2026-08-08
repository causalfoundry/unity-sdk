using UnityEngine;

namespace CausalFoundry.Unity
{
    /// <summary>
    /// Build-time and runtime SDK settings. Place one asset at
    /// Assets/Resources/CausalFoundrySettings.asset to enable automatic initialization and native
    /// early-lifecycle configuration.
    /// </summary>
    [CreateAssetMenu(fileName = ResourceName, menuName = "Causal Foundry/SDK Settings")]
    public sealed class CFSettings : ScriptableObject
    {
        public const string ResourceName = "CausalFoundrySettings";

        [SerializeField] private string sdkKey = string.Empty;
        [SerializeField] private bool autoInitialize = true;
        [SerializeField] private bool allowAnonymousUsers = true;
        [SerializeField] private bool updateImmediately;
        [SerializeField]
        [Tooltip("Disable before initialization only to suppress automatic native in-app messages.")]
        private bool autoShowInAppMessages = true;
        [SerializeField] private bool disableAutoPageTracking = true;
        [SerializeField] private bool pauseSdk;
        [SerializeField] private bool enableDebugMode = true;

        public string SdkKey
        {
            get { return CFSDK.NormalizeSdkKey(sdkKey) ?? string.Empty; }
            set { sdkKey = CFSDK.NormalizeSdkKey(value) ?? string.Empty; }
        }

        public bool AutoInitialize
        {
            get { return autoInitialize; }
            set { autoInitialize = value; }
        }

        public bool AllowAnonymousUsers
        {
            get { return allowAnonymousUsers; }
            set { allowAnonymousUsers = value; }
        }

        public bool UpdateImmediately
        {
            get { return updateImmediately; }
            set { updateImmediately = value; }
        }

        public bool AutoShowInAppMessages
        {
            get { return autoShowInAppMessages; }
            set { autoShowInAppMessages = value; }
        }

        public bool DisableAutoPageTracking
        {
            get { return disableAutoPageTracking; }
            set { disableAutoPageTracking = value; }
        }

        public bool PauseSdk
        {
            get { return pauseSdk; }
            set { pauseSdk = value; }
        }

        public bool EnableDebugMode
        {
            get { return enableDebugMode; }
            set { enableDebugMode = value; }
        }

        public CFOptions CreateOptions()
        {
            return new CFOptions
            {
                AllowAnonymousUsers = allowAnonymousUsers,
                UpdateImmediately = updateImmediately,
                AutoShowInAppMessages = autoShowInAppMessages,
                DisableAutoPageTracking = disableAutoPageTracking,
                PauseSdk = pauseSdk,
                EnableDebugMode = enableDebugMode
            };
        }

        public static CFSettings LoadFromResources()
        {
            return Resources.Load<CFSettings>(ResourceName);
        }
    }

    internal static class CFAutoInitializer
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void InitializeBeforeFirstScene()
        {
            CFSettings settings = CFSettings.LoadFromResources();
            if (settings == null || !settings.AutoInitialize || IsBlank(settings.SdkKey))
            {
                return;
            }

            CFSDK.Initialize(settings.SdkKey, settings.CreateOptions());
        }

        private static bool IsBlank(string value)
        {
            return string.IsNullOrEmpty(value) || value.Trim().Length == 0;
        }
    }
}
