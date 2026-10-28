import QtQuick
import QtTest
import "../ToastPolicy.js" as ToastPolicy
import "../HistoryPolicy.js" as HistoryPolicy

TestCase {
    name: "ToastExitRetention"

    function test_transients_do_not_enter_history() {
        const normal = { appName: "test", transient: false }
        const temporary = { appName: "test", transient: true }
        const history = HistoryPolicy.visibleNotifications([normal, temporary], [])
        compare(history.length, 1)
        compare(history[0], normal)
    }

    function test_removedCardKeepsItsSlot() {
        const first = { id: 1 }
        const second = { id: 2 }
        const rendered = ToastPolicy.retainForExit([second], [first, second])
        compare(rendered.length, 2)
        compare(rendered[0], first)
        compare(rendered[1], second)
    }

    function test_newCardPrecedesRetiringCards() {
        const old = { id: 1 }
        const fresh = { id: 2 }
        const rendered = ToastPolicy.retainForExit([fresh], [old])
        compare(rendered[0], fresh)
        compare(rendered[1], old)
    }

    function test_hideRetainsAllUntilExit() {
        const cards = [{ id: 1 }, { id: 2 }]
        compare(ToastPolicy.retainForExit([], cards), cards)
    }

    function test_reopenDoesNotDuplicateCard() {
        const card = { id: 1 }
        const rendered = ToastPolicy.retainForExit([card], [card])
        compare(rendered.length, 1)
        compare(rendered[0], card)
    }

    function test_burstBoundsRetiringCards() {
        let active = []
        let rendered = []
        for (let i = 0; i < 100; ++i) {
            active = [{id: i}].concat(active).slice(0, 3)
            rendered = ToastPolicy.retainForExit(active, rendered, 3)
            verify(rendered.length <= 6)
            for (const card of active)
                verify(rendered.indexOf(card) !== -1)
        }
    }
}
