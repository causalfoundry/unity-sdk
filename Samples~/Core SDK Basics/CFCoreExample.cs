using System;
using System.Collections.Generic;
using CausalFoundry.Unity;
using UnityEngine;

public sealed class CFCoreExample : MonoBehaviour
{
    private const string SampleUserIdKey = "CausalFoundry.Kenkai.SampleUserId";

    [SerializeField]
    [Tooltip("Optional authenticated player ID. Leave blank to create a stable ID for this installation.")]
    private string userId = string.Empty;

    private void OnEnable()
    {
        CFSDK.ActionOpened += OnActionOpened;
    }

    private void OnDisable()
    {
        CFSDK.ActionOpened -= OnActionOpened;
    }

    private void Start()
    {
        CFSettings settings = CFSettings.LoadFromResources();
        if (settings == null || string.IsNullOrEmpty(settings.SdkKey))
        {
            Debug.LogError("Create the Causal Foundry SDK settings asset before running this sample.");
            return;
        }

        bool isNewIdentity;
        string resolvedUserId = ResolveUserId(out isNewIdentity);

        CFSDK.Initialize(
            settings.SdkKey,
            settings.CreateOptions(),
            delegate(CFResult initialization)
            {
                if (!initialization.IsSuccess)
                {
                    Debug.LogError(initialization.Error);
                    return;
                }

                CFSDK.Identify(
                    resolvedUserId,
                    isNewIdentity ? IdentityAction.Register : IdentityAction.Login,
                    null,
                    delegate(CFResult identity)
                    {
                        if (!identity.IsSuccess)
                        {
                            Debug.LogError(identity.Error);
                            return;
                        }

                        if (isNewIdentity)
                        {
                            PlayerPrefs.SetString(SampleUserIdKey, resolvedUserId);
                            PlayerPrefs.Save();
                        }

                        CFSDK.LogUserCatalog(
                            resolvedUserId,
                            new UserCatalogOptions
                            {
                                Country = "Spain",
                                Metadata = new Dictionary<string, string>
                                {
                                    { "role", "game_user" }
                                }
                            },
                            delegate(CFResult catalog)
                            {
                                if (!catalog.IsSuccess)
                                {
                                    Debug.LogError(catalog.Error);
                                }

                                CFSDK.Track(
                                    "unity_sample_started",
                                    new TrackOptions
                                    {
                                        Property = "core_sample"
                                    });
                            });
                    });
            });
    }

    public void FetchCustomActions()
    {
        CFSDK.FetchActions(
            invActionType: ActionTypes.Custom,
            actionRenderMethodType: ActionRenderMethods.InAppComponent,
            deliveryMode: ActionDeliveryModes.OneOff,
            actionAttributes: new Dictionary<string, string>
            {
                { "screen", "unity_sample" }
            },
            completion: delegate(CFResult<IList<CFAction>> result)
            {
                if (!result.IsSuccess)
                {
                    Debug.LogError(result.Error);
                    return;
                }

                Debug.Log("Fetched " + result.Value.Count + " Causal Foundry action(s).");
            });
    }

    /// <summary>Connect this to an onboarding button after explaining notification benefits.</summary>
    public void RequestNotificationPermission()
    {
        CFSDK.RequestNotificationPermission(
            delegate(CFResult<NotificationPermissionStatus> result)
            {
                if (!result.IsSuccess)
                {
                    Debug.LogError(result.Error);
                    return;
                }

                Debug.Log("Notification permission: " + result.Value);
            });
    }

    public void ShowDefaultInAppMessage()
    {
        CFSDK.ShowInAppMessage(ActionScreens.Default);
    }

    private static void OnActionOpened(ActionOpenedEvent opened)
    {
        Debug.Log("Causal Foundry action opened: " + opened.CtaType + " / " + opened.CtaId);
    }

    private string ResolveUserId(out bool isNewIdentity)
    {
        if (!string.IsNullOrEmpty(userId) && userId.Trim().Length > 0)
        {
            isNewIdentity = false;
            return userId.Trim();
        }

        string persisted = PlayerPrefs.GetString(SampleUserIdKey, string.Empty);
        isNewIdentity = string.IsNullOrEmpty(persisted) || persisted.Trim().Length == 0;
        if (!isNewIdentity)
        {
            return persisted;
        }

        persisted = "unity-" + Guid.NewGuid().ToString("N");
        return persisted;
    }
}
