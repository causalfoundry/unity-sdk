namespace CausalFoundry.Unity
{
    /// <summary>Identity lifecycle actions supported by both native Core SDKs.</summary>
    public enum IdentityAction
    {
        Register = 0,
        Login = 1,
        Logout = 2,
        Blocked = 3,
        Unblocked = 4
    }

    internal static class IdentityActionWireValue
    {
        internal static bool TryGet(IdentityAction action, out string value)
        {
            switch (action)
            {
                case IdentityAction.Register:
                    value = "register";
                    return true;
                case IdentityAction.Login:
                    value = "login";
                    return true;
                case IdentityAction.Logout:
                    value = "logout";
                    return true;
                case IdentityAction.Blocked:
                    value = "blocked";
                    return true;
                case IdentityAction.Unblocked:
                    value = "unblocked";
                    return true;
                default:
                    value = null;
                    return false;
            }
        }
    }
}
