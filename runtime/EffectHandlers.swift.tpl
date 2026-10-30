import Foundation
import SwiftUI

class EffectHandlers {
    private weak var viewModel: OrbitalViewModel?

    init(viewModel: OrbitalViewModel) {
        self.viewModel = viewModel
    }

    /// Applies one `clientEffectsByTrait` entry's effect — the sole owner of render-ui
    /// indexing/slot-writing and `emit` re-dispatch (mirrors `ClientCore`'s
    /// `execute_client_effect` + its render-ui indexing pass in
    /// `process_response`). `requestTrait` is the trait the event that
    /// produced this response was sent to; render-ui/emit fall back to it
    /// when the effect carries no `sourceTrait` of its own.
    func apply(effect: AnyCodable, requestTrait: String) {
        guard let arr = effect.arrayValue, let kind = arr.first?.stringValue else { return }
        switch kind {
        case "render-ui":
            guard arr.count >= 3 else { return }
            let slot = arr[1].stringValue ?? "main"
            let content = arr[2]
            let isClear: Bool = { if case .null = content { return true }; return false }()
            let source = content.dictValue?["sourceTrait"]?.stringValue ?? requestTrait
            if slotRole(slot) == .main {
                // Per-trait index only — the page body stacks `traitContent[trait]` for every
                // live main writer, so a main render-ui is never written to `uiSlots`.
                if isClear {
                    viewModel?.traitContent.removeValue(forKey: source)
                    viewModel?.mainOrder.removeAll(where: { $0 == source })
                    if viewModel?.lastMainWriter == source { viewModel?.lastMainWriter = nil }
                } else {
                    viewModel?.traitContent[source] = content
                    if !OrbitalViewModel.embeddedTraits.contains(source) {
                        if viewModel?.mainOrder.contains(source) == false { viewModel?.mainOrder.append(source) }
                        viewModel?.lastMainWriter = source
                    }
                }
            } else if isClear {
                viewModel?.uiSlots.removeValue(forKey: slot)
            } else {
                viewModel?.uiSlots[slot] = content
                if viewModel?.traitContent[source] == nil {
                    viewModel?.traitContent[source] = content
                }
            }
        case "navigate":
            if let path = arr[1].stringValue {
                viewModel?.navigate(to: path)
            }
        case "navigate-back":
            if viewModel?.navigationPath.isEmpty == false {
                viewModel?.navigationPath.removeLast()
            }
        case "host-ask":
            // A `runsOn: client` host-port effect (`auth/sign-out`, `auth/sign-in`); the view model answers it or refuses it by name,
            // and returns the answer of one that declared routes to its fourth element's trait.
            guard let op = arr[safe: 1]?.stringValue else { return }
            viewModel?.answerHostAsk(op: op, args: arr[safe: 2]?.arrayValue ?? [], completion: arr[safe: 3])
        case "notify":
            let title = arr[safe: 1]?.stringValue ?? ""
            let message = arr[safe: 2]?.stringValue ?? ""
            viewModel?.alertMessage = title.isEmpty ? message : "\(title): \(message)"
        case "emit":
            guard let event = arr[safe: 1]?.stringValue else { return }
            AlmadarBus.shared.post(event, arr[safe: 2])
            viewModel?.sendEvent(trait: requestTrait, event: event, payload: arr[safe: 2])
        default:
            break
        }
    }
}
