//
//  File.swift
//
//
//  Created by khushbu on 09/10/23.
//
import Foundation

class ExceptionError: Error {
    init() {}

    init(message _: String) {}

    init(message _: String, cause _: Error) {}

    init(cause _: Error) {}

    init(message _: String, cause _: Error?, enableSuppression _: Bool, writableStackTrace _: Bool) {}

    @available(*, unavailable)
    required init?(coder _: NSCoder) {}
}

class IllegalArgumentException: ExceptionError {
    var message: String = "Illegal Argument"

    override public init() {
        super.init()
    }

    public init(_ message: String) {
        super.init(message: message)
        self.message = message
    }

    override public init(message: String, cause: Error) {
        super.init(message: message, cause: cause)
        self.message = message + ": " + cause.localizedDescription
    }

    override public init(cause: Error) {
        super.init(cause: cause)
        message = cause.localizedDescription
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class IllegalStateException: ExceptionError {
    var message: String = "Illegal State"
    var line: String?
    var className: String?

    override public init() {
        super.init()
    }

    public init(_ message: String) {
        super.init(message: message)
        self.message = message
    }

    override public init(message: String, cause: Error) {
        super.init(message: message, cause: cause)
        self.message = message + ": " + cause.localizedDescription
    }

    override public init(cause: Error) {
        super.init(cause: cause)
        message = cause.localizedDescription
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NullPointerException: ExceptionError {
    var message: String = "Null Pointer Exception"

    override public init() {
        super.init()
    }

    public init(_ message: String) {
        super.init(message: message)
        self.message = message
    }

    override public init(message: String, cause: Error) {
        super.init(message: message, cause: cause)
        self.message = message + ": " + cause.localizedDescription
    }

    override public init(cause: Error) {
        super.init(cause: cause)
        message = cause.localizedDescription
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RuntimeException: ExceptionError {
    var message: String = "RunTime Exception"

    override init() {
        super.init()
    }

    init(_ message: String) {
        super.init(message: message)
        self.message = message
    }

    init(_ message: String, cause: Error?) {
        // Ignoring cause for simplicity in this example
        super.init(message: message, cause: cause!)
        self.message = message
    }

    override init(cause: Error?) {
        super.init(cause: cause!)
        // Ignoring cause for simplicity in this example
        message = ""
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
