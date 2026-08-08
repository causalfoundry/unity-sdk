namespace CausalFoundry.Unity
{
    /// <summary>The operating-system authorization state returned by a notification request.</summary>
    public enum NotificationPermissionStatus
    {
        /// <summary>No status is available, normally because the containing result failed.</summary>
        Unknown = 0,

        /// <summary>The operating system allows this application to present notifications.</summary>
        Authorized = 1,

        /// <summary>The user or operating system denied notification authorization.</summary>
        Denied = 2,

        /// <summary>This Android version does not use a notification runtime permission.</summary>
        NotRequired = 3
    }

    /// <summary>Stable error categories returned by the Unity wrapper.</summary>
    public enum CFErrorCode
    {
        None = 0,
        InvalidArgument = 1,
        NotInitialized = 2,
        InitializationInProgress = 3,
        AlreadyInitialized = 4,
        UnsupportedPlatform = 5,
        NativeFailure = 6,
        SerializationFailure = 7,
        InvalidResponse = 8,
        Timeout = 9,
        Unknown = 10
    }

    /// <summary>Information about a failed SDK operation.</summary>
    public sealed class CFError
    {
        internal CFError(CFErrorCode code, string message, string nativeCode)
        {
            Code = code;
            Message = message ?? string.Empty;
            NativeCode = nativeCode ?? string.Empty;
        }

        public CFErrorCode Code { get; private set; }

        public string Message { get; private set; }

        /// <summary>The native error identifier, when the platform SDK supplied one.</summary>
        public string NativeCode { get; private set; }

        public override string ToString()
        {
            if (string.IsNullOrEmpty(NativeCode))
            {
                return Code + ": " + Message;
            }

            return Code + " (" + NativeCode + "): " + Message;
        }
    }

    /// <summary>Result of an SDK operation that does not return data.</summary>
    public class CFResult
    {
        internal CFResult(bool isSuccess, CFError error)
        {
            IsSuccess = isSuccess;
            Error = error;
        }

        public bool IsSuccess { get; private set; }

        /// <summary>Null when <see cref="IsSuccess"/> is true.</summary>
        public CFError Error { get; private set; }

        internal static CFResult Succeeded()
        {
            return new CFResult(true, null);
        }

        internal static CFResult Failed(
            CFErrorCode code,
            string message,
            string nativeCode)
        {
            return new CFResult(false, new CFError(code, message, nativeCode));
        }
    }

    /// <summary>Result of an SDK operation that returns data.</summary>
    public sealed class CFResult<T> : CFResult
    {
        private CFResult(bool isSuccess, T value, CFError error)
            : base(isSuccess, error)
        {
            Value = value;
        }

        public T Value { get; private set; }

        internal static CFResult<T> Succeeded(T value)
        {
            return new CFResult<T>(true, value, null);
        }

        internal new static CFResult<T> Failed(
            CFErrorCode code,
            string message,
            string nativeCode)
        {
            return new CFResult<T>(
                false,
                default(T),
                new CFError(code, message, nativeCode));
        }
    }
}
