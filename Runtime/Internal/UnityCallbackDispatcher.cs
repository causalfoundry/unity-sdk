using System;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

namespace CausalFoundry.Unity.Internal
{
    /// <summary>Posts public SDK callbacks to Unity's captured main-thread synchronization context.</summary>
    internal static class UnityCallbackDispatcher
    {
        private static readonly object Sync = new object();
        private static readonly Queue<Action> Pending = new Queue<Action>();
        private static SynchronizationContext unityContext;
        private static int unityThreadId;
        private static bool unityThreadCaptured;
        private static bool pumpCreated;

        static UnityCallbackDispatcher()
        {
#if UNITY_EDITOR
            // EditMode tests and editor tooling do not run the player startup hooks. Their first
            // touch normally occurs on the editor thread, so capture it for synchronous behavior.
            CaptureCurrentThread();
#endif
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void CaptureAtStartup()
        {
            lock (Sync)
            {
                // Handles Enter Play Mode with domain reload disabled: the previous pump is gone
                // even though managed static fields can survive.
                pumpCreated = false;
            }
            CaptureCurrentThread();
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void InstallFallbackPump()
        {
            CaptureCurrentThread();

            lock (Sync)
            {
                if (pumpCreated)
                {
                    return;
                }
                pumpCreated = true;
            }

            var pumpObject = new GameObject("Causal Foundry Callback Dispatcher");
            pumpObject.hideFlags = HideFlags.HideAndDontSave;
            UnityEngine.Object.DontDestroyOnLoad(pumpObject);
            pumpObject.AddComponent<UnityCallbackDispatcherPump>();
        }

        internal static void Run(Action action)
        {
            if (action == null)
            {
                return;
            }

            SynchronizationContext context;
            int threadId;
            lock (Sync)
            {
                if (!unityThreadCaptured)
                {
                    Pending.Enqueue(action);
                    return;
                }

                context = unityContext;
                threadId = unityThreadId;

                if (Thread.CurrentThread.ManagedThreadId != threadId && context == null)
                {
                    // Some older/player hosts do not install a SynchronizationContext. The hidden
                    // pump drains this queue from Unity's main thread on its next Update.
                    Pending.Enqueue(action);
                    return;
                }
            }

            if (Thread.CurrentThread.ManagedThreadId == threadId)
            {
                action();
                return;
            }

            context.Post(delegate(object state) { action(); }, null);
        }

        private static void CaptureCurrentThread()
        {
            Action[] pending;
            lock (Sync)
            {
                unityContext = SynchronizationContext.Current;
                unityThreadId = Thread.CurrentThread.ManagedThreadId;
                unityThreadCaptured = true;
                pending = Pending.ToArray();
                Pending.Clear();
            }

            for (int i = 0; i < pending.Length; i++)
            {
                pending[i]();
            }
        }

        internal static void DrainPendingOnMainThread()
        {
            Action[] pending;
            lock (Sync)
            {
                if (!unityThreadCaptured ||
                    Thread.CurrentThread.ManagedThreadId != unityThreadId ||
                    Pending.Count == 0)
                {
                    return;
                }

                pending = Pending.ToArray();
                Pending.Clear();
            }

            for (int i = 0; i < pending.Length; i++)
            {
                pending[i]();
            }
        }
    }

    internal sealed class UnityCallbackDispatcherPump : MonoBehaviour
    {
        private void Update()
        {
            UnityCallbackDispatcher.DrainPendingOnMainThread();
        }
    }
}
