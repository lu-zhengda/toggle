import AppKit

/// Performs the privileged Low Power Mode change with one retained, invariant
/// AppleScript. macOS caches administrator approval only for the exact same
/// script, so interpolating `0` or `1` into fresh source forces needless
/// reauthentication when the user toggles in the opposite direction.
enum LowPowerMode {
    enum ChangeResult: Equatable, Sendable {
        case success
        case cancelled
        case failure(String)
    }

    static let scriptSource = """
    on setLowPowerMode(requestedState)
        set stateValue to requestedState as text
        if stateValue is not "0" and stateValue is not "1" then
            error "Invalid Low Power Mode state."
        end if
        do shell script "/usr/bin/pmset -a lowpowermode " & stateValue with administrator privileges
        return stateValue
    end setLowPowerMode
    """

    nonisolated(unsafe) private static let script = NSAppleScript(source: scriptSource)
    private static let queue = DispatchQueue(label: "com.local.toggle.low-power-mode")

    static func argument(for enabled: Bool) -> String {
        enabled ? "1" : "0"
    }

    static func setEnabled(_ enabled: Bool) -> ChangeResult {
        queue.sync {
            guard let script else {
                return .failure("The administrator script could not be created.")
            }

            if !script.isCompiled {
                var compilationError: NSDictionary?
                guard script.compileAndReturnError(&compilationError) else {
                    return classify(output: nil, error: compilationError)
                }
            }

            let (output, error) = execute(
                script: script,
                handler: "setLowPowerMode",
                argument: argument(for: enabled)
            )
            return classify(output: output, error: error)
        }
    }

    /// Invoke an AppleScript handler using a parameter instead of changing the
    /// script source. Kept internal so tests can verify the event bridge without
    /// executing the privileged script.
    static func execute(
        script: NSAppleScript,
        handler: String,
        argument: String
    ) -> (output: NSAppleEventDescriptor?, error: NSDictionary?) {
        let event = NSAppleEventDescriptor(
            eventClass: 0x6173_6372,       // 'ascr'
            eventID: 0x7073_6272,          // 'psbr'
            targetDescriptor: nil,
            returnID: -1,
            transactionID: 0
        )
        event.setParam(
            NSAppleEventDescriptor(string: handler),
            forKeyword: 0x736E_616D        // 'snam'
        )

        let arguments = NSAppleEventDescriptor.list()
        arguments.insert(NSAppleEventDescriptor(string: argument), at: 1)
        event.setParam(arguments, forKeyword: 0x2D2D_2D2D) // '----'

        var error: NSDictionary?
        let output = script.executeAppleEvent(event, error: &error)
        return (output, error)
    }

    static func classify(
        output: NSAppleEventDescriptor?,
        error: NSDictionary?
    ) -> ChangeResult {
        if output != nil { return .success }

        let number = (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        if number == -128 || number == -60006 {
            return .cancelled
        }

        if let message = error?[NSAppleScript.errorMessage] as? String, !message.isEmpty {
            return .failure(message)
        }
        return .failure("Administrator approval failed.")
    }
}
