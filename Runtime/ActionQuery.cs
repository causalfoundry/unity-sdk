using System.Collections.Generic;

namespace CausalFoundry.Unity
{
    /// <summary>
    /// String-based action query. This avoids exposing platform-specific native enum types; actual
    /// value support is determined by the native Core versions bundled with this package.
    /// </summary>
    public sealed class ActionQuery
    {
        public ActionQuery()
        {
            Type = ActionTypes.Message;
            RenderMethod = ActionRenderMethods.InAppMessage;
            DeliveryMode = ActionDeliveryModes.OneOff;
        }

        public ActionQuery(string type, string renderMethod, string deliveryMode)
        {
            Type = type;
            RenderMethod = renderMethod;
            DeliveryMode = deliveryMode;
        }

        public string Type { get; set; }

        public string RenderMethod { get; set; }

        public string DeliveryMode { get; set; }

        /// <summary>String attributes used to filter native actions.</summary>
        public IDictionary<string, string> Attributes { get; set; }
    }

    public static class ActionTypes
    {
        public const string Message = "message";
        public const string Custom = "custom";

        /// <summary>The iOS Core SDK spelling for a custom UI component action.</summary>
        public const string UiComponent = "ui-component";
    }

    public static class ActionRenderMethods
    {
        public const string PushNotification = "push_notification";
        public const string InAppMessage = "in_app_message";
        public const string InAppComponent = "in_app_component";
    }

    public static class ActionDeliveryModes
    {
        public const string OneOff = "one-off";
        public const string Cached = "cached";
    }

    public static class ActionScreens
    {
        public const string Default = "";
        public const string Home = "home";
        public const string Search = "search";
        public const string Product = "product";
        public const string Cart = "cart";
        public const string Checkout = "checkout";
        public const string Reminder = "reminder";
        public const string Favorite = "favorite";
        public const string Other = "other";
    }
}
