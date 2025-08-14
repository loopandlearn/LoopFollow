// LoopFollow
// ObservableUserDefaultsValue.swift

import Combine
import Foundation

class ObservableUserDefaultsValue<T: AnyConvertible & Equatable>: ObservableObject, UserDefaultsAnyValue {
    // user defaults key (UserDefaultsAnyValue protocol implementation)
    let key: String
    typealias ValueType = T

    // The value (strong typed)
    @Published var value: T {
        didSet {
            // Continue only if the new value is different from the old value
            guard value != oldValue else { return }

            if let validation = validation {
                guard let validatedValue = validation(value) else {
                    DispatchQueue.main.async {
                        self.value = oldValue
                    }
                    return
                }
                value = validatedValue
            }

            // Store value to user defaults
            ObservableUserDefaultsValue.defaults.setValue(value.toAny(), forKey: key)

            // Execute custom closure
            DispatchQueue.main.async {
                self.onChange?(self.value)

                // Notify observers
                self.observers.values.forEach { $0(self.value) }

                // Notify UserDefaultsValueGroups that value has changed
                UserDefaultsValueGroups.valueChanged(self)

                print("Value for \(self.key) changed to \(self.value)") // Logging
            }
        }
    }

    /// Get/set the value from Any value (UserDefaultsAnyValue protocol implementation)
    var anyValue: Any? {
        get {
            return value.toAny()
        }
        set {
            guard let newValue = T.fromAny(newValue) as T? else {
                return
            }
            DispatchQueue.main.async {
                self.value = newValue
            }
        }
    }

    /// Is there this key already stored in UserDefaults?
    var exists: Bool {
        return ObservableUserDefaultsValue.defaults.object(forKey: key) != nil
    }

    // On change closure
    private let onChange: ((T) -> Void)?

    // Validate & transform closure : given the new value, validate it; if validation passes, return the new value;
    // if validation fails, transform the value, returning a modified version or return nil and the change will not happen
    private let validation: ((T) -> T?)?

    // Value change observers
    private var observers: [UUID: (T) -> Void] = [:]

    // User defaults used for persistence
    private class var defaults: UserDefaults {
        return UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    }

    init(key: String, default defaultValue: T, onChange: ((T) -> Void)? = nil, validation: ((T) -> T?)? = nil) {
        self.key = key
        self.onChange = onChange
        self.validation = validation

        if let anyValue = ObservableUserDefaultsValue.defaults.object(forKey: key), let value = T.fromAny(anyValue) as T? {
            self.value = validation?(value) ?? value
        } else {
            value = defaultValue
        }
    }

    /// Insert this value in a group, useful for observing changes in the whole group, instead of particular values
    func group(_ groupName: String) -> Self {
        UserDefaultsValueGroups.add(self, to: groupName)
        return self
    }

    /// Register observers, will be notified when value changes
    @discardableResult
    func observeChanges(using closure: @escaping (T) -> Void) -> ObservationToken {
        let id = UUID()
        observers[id] = closure

        return ObservationToken { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setNil(key: String) {
        ObservableUserDefaultsValue.defaults.removeObject(forKey: key)
    }
}
