import ".."
import "../HistoryModel.js" as Model
import "../HistoryPolicy.js" as HistoryPolicy
import "../ToastPolicy.js" as ToastPolicy
import QtQuick
import QtQuick.Window
import QtTest

Item {
    id: host

    width: 380
    height: 650
    focus: true
    Keys.onPressed: (event) => {
        if (test.state && test.state.handleKey(event.key, event.modifiers, event.text))
            event.accepted = true;

    }

    QtObject {
        id: config

        property color fg: "white"
        property color muted: "#888888"
        property color bg: "#111111"
        property color urgent: "red"
        property color selectionBackground: "#b8865e"
        property color selectionForeground: "#18120d"
        property string textFontFamily: "sans-serif"
        property string iconFontFamily: "sans-serif"
        property real iconSize: 10
        property int popupRadius: 4

        function fontSize(scale) {
            return 10 * scale;
        }

    }

    QtObject {
        id: service

        property var notifications: []
        property var calls: []

        function dismiss(note) {
            calls = calls.concat(["dismiss:" + note.id]);
            notifications = notifications.filter((item) => {
                return item.id !== note.id;
            });
        }

        function clearAll() {
            calls = calls.concat(["clear"]);
            notifications = [];
        }

    }

    Component {
        id: stateComponent

        HistoryState {
            notificationService: service
        }

    }

    Component {
        id: cardComponent

        HistoryCard {
        }

    }

    TestCase {
        id: test

        property var state: null
        property var card: null
        property int closes: 0

        function action(id, label) {
            return {
                "identifier": id,
                "text": label,
                "invoke": () => {
                    service.calls = service.calls.concat(["action:" + id]);
                }
            };
        }

        function notification(id, actions) {
            return {
                "id": id,
                "appName": "Test",
                "summary": "Notification " + id,
                "body": "Body",
                "actions": actions || [],
                "image": "",
                "appIcon": ""
            };
        }

        function press(key, modifiers, text) {
            return state.handleKey(key, modifiers || Qt.NoModifier, text || "");
        }

        function init() {
            failOnWarning(/TypeError|Binding loop/);
            closes = 0;
            service.calls = [];
            service.notifications = [notification(1), notification(2), notification(3)];
            state = createTemporaryObject(stateComponent, host);
            verify(state !== null);
            state.closeRequested.connect(() => {
                return closes++;
            });
        }

        function cleanup() {
            if (card)
                card.destroy();

            if (state)
                state.destroy();

            wait(0);
            card = null;
            state = null;
        }

        function test_newest_first_and_navigation() {
            compare(state.selectedNotification.id, 3);
            press(Qt.Key_Down);
            compare(state.selectedNotification.id, 2);
            press(Qt.Key_J);
            compare(state.selectedNotification.id, 1);
            press(Qt.Key_Down);
            compare(state.selectedNotification.id, 1);
            press(Qt.Key_K);
            compare(state.selectedNotification.id, 2);
            press(Qt.Key_Up);
            compare(state.selectedNotification.id, 3);
            press(Qt.Key_Tab);
            compare(state.selectedNotification.id, 2);
            press(Qt.Key_Tab, Qt.ShiftModifier);
            compare(state.selectedNotification.id, 3);
        }

        function test_selection_survives_arrivals_and_removal() {
            state.select(1);
            service.notifications = service.notifications.concat([notification(4)]);
            compare(state.selectedNotification.id, 2);
            compare(state.selectedIndex, 2);
            press(Qt.Key_X);
            compare(service.calls, ["dismiss:2"]);
            compare(state.selectedNotification.id, 1);
            press(Qt.Key_X);
            compare(state.selectedNotification.id, 3);
        }

        function test_expansion_state_tracks_notification_id() {
            state.select(1);
            state.toggleExpanded(state.selectedNotification.id);
            compare(state.expandedId, "2");
            state.toggleExpanded(state.selectedNotification.id);
            compare(state.expandedId, "");

            state.toggleExpanded(2);
            service.notifications = [notification(1)];
            compare(state.expandedId, "");
        }

        function test_x_dismisses_and_ctrl_x_clears() {
            verify(!press(Qt.Key_C));
            compare(service.calls, []);
            press(Qt.Key_X);
            compare(service.calls, ["dismiss:3"]);
            compare(service.notifications.length, 2);
            verify(!press(Qt.Key_C, Qt.ControlModifier));
            compare(service.calls, ["dismiss:3"]);
            press(Qt.Key_X, Qt.ControlModifier);
            compare(service.calls, ["dismiss:3", "clear"]);
            compare(state.selectedIndex, -1);
            compare(state.selectedNotification, null);
            press(Qt.Key_X);
            press(Qt.Key_Return);
            press(Qt.Key_Down);
        }

        function test_real_key_events_reach_controller() {
            host.forceActiveFocus();
            tryVerify(() => {
                return host.activeFocus;
            });
            keyClick(Qt.Key_Down);
            compare(state.selectedNotification.id, 2);
            keyClick(Qt.Key_X);
            compare(service.calls, ["dismiss:2"]);
            keyClick(Qt.Key_X, Qt.ControlModifier);
            compare(service.notifications.length, 0);
            keyClick(Qt.Key_Escape);
            compare(closes, 1);
        }

        function test_close_action_is_local_dismissal() {
            service.notifications = [notification(5, [action("close", "Close")])];
            compare(state.actions, []);
            press(Qt.Key_X);
            compare(service.calls, ["dismiss:5"]);
        }

        function test_duplicate_labels_keep_one_button_but_preserve_default() {
            service.notifications = [notification(5, [action("edit", "Edit"), action("default", "Edit"), action("open", "Open"), action("close", "Close")])];
            compare(state.actions.map((entry) => {
                return entry.label;
            }), ["Edit", "Open"]);
            press(Qt.Key_Return);
            press(Qt.Key_E, Qt.NoModifier, "e");
            compare(service.calls, ["action:default", "action:edit"]);
        }

        function test_c_can_be_an_action_shortcut() {
            service.notifications = [notification(5, [action("copy", "Copy")])];
            compare(state.actions[0].key, "c");
            press(Qt.Key_C, Qt.NoModifier, "c");
            compare(service.calls, ["action:copy"]);
            compare(service.notifications.length, 1);
            verify(!press(Qt.Key_C, Qt.ControlModifier));
            compare(service.calls, ["action:copy"]);
            press(Qt.Key_X, Qt.ControlModifier);
            compare(service.calls, ["action:copy", "clear"]);
        }

        function test_action_shortcuts_and_default() {
            service.notifications = [notification(5, [action("default", "Open"), action("reply", "Reply")])];
            verify(press(Qt.Key_O, Qt.NoModifier, "o"));
            press(Qt.Key_R, Qt.NoModifier, "r");
            press(Qt.Key_Return);
            compare(service.calls, ["action:default", "action:reply", "action:default"]);
            compare(service.notifications.length, 1);
        }

        function test_enter_does_not_invent_default_action() {
            service.notifications = [notification(5, [action("reply", "Reply")])];
            press(Qt.Key_Return);
            compare(service.calls.length, 0);
        }

        function test_reserved_keys_and_collisions() {
            const entries = Model.actionsFor([action("open", "Open"), action("options", "Options"), action("copy", "Copy"), action("jump", "Jump"), action("close", "Close"), action("close2", "Close")]);
            const keys = entries.map((item) => {
                return item.key;
            });
            compare(new Set(keys).size, keys.length);
            verify(!entries.some((item) => {
                return item.label === "Close";
            }));
            compare(entries[0].key, "o");
            verify(!keys.includes("x"));
            verify(!keys.includes("j"));
            verify(!keys.includes("k"));
            compare(Model.actionsFor([]), []);
        }

        function test_escape_and_modifiers() {
            verify(!press(Qt.Key_Question, Qt.ShiftModifier, "?"));
            verify(!press(Qt.Key_C, Qt.ControlModifier));
            press(Qt.Key_X, Qt.ControlModifier);
            compare(service.calls, ["clear"]);
            press(Qt.Key_Escape);
            compare(closes, 1);
        }

        function findText(item, value) {
            if (item.text === value)
                return item;

            for (const child of item.children || []) {
                const match = findText(child, value);
                if (match)
                    return match;

            }
            return null;
        }

        function test_history_card_is_plain_and_selection_is_opt_in() {
            const note = notification(1, [action("default", "Open")]);
            note.summary = "<b>Literal title</b>";
            card = createTemporaryObject(cardComponent, host, {
                "width": 340,
                "config": config,
                "notification": note,
                "timeLabel": "12:34",
                "actionEntries": Model.actionsFor(note.actions)
            });
            verify(card !== null);
            waitForPolish(host.Window.window);
            verify(card.implicitHeight > 0);
            compare(findText(card, "Test"), null);
            compare(findText(card, note.summary).color, config.fg);
            compare(findText(card, "12:34").color, config.muted);
            compare(findText(card, note.summary).textFormat, Text.PlainText);
            compare(findText(card, "[o] Open"), null);
            const unselectedHeight = card.implicitHeight;
            card.selected = true;
            waitForPolish(host.Window.window);
            compare(findText(card, note.summary).color, config.fg);
            compare(findText(card, "12:34").color, config.fg);
            verify(findText(card, "[o] Open") !== null);
            compare(findText(card, "[c] Close"), null);
            verify(card.implicitHeight > unselectedHeight);
        }

        function test_image_hints_are_icons_not_large_previews() {
            compare(Model.iconFromImage("image://icon/camera"), "camera");

            const note = notification(1);
            note.image = "file:///tmp/screenshot.png";
            const fallbackIcon = "data:image/svg+xml," + encodeURIComponent(
                '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="blue"/></svg>');
            card = createTemporaryObject(cardComponent, host, {
                width: 340, height: 100, config: config, selected: true,
                notification: note, appIconSource: fallbackIcon
            });
            verify(findChild(card, "historyAppIcon").source.toString().startsWith("data:image/svg+xml,"));
            compare(findChild(card, "historyImagePreview"), null);
            const iconBox = findChild(card, "historyIconBox");
            verify(iconBox.x > card.width / 2);
            compare(iconBox.y + iconBox.height / 2, card.height / 2);
        }

        function test_low_urgency_toast_policy() {
            verify(ToastPolicy.shouldShow({urgency: 0, lastGeneration: false}, false));
            verify(ToastPolicy.shouldShow({urgency: 1, lastGeneration: false}, false));
            verify(ToastPolicy.shouldShow({urgency: 2, lastGeneration: false}, false));
            verify(!ToastPolicy.shouldShow({urgency: 0, lastGeneration: false}, true));
            verify(!ToastPolicy.shouldShow({urgency: 1, lastGeneration: true}, false));
            verify(!ToastPolicy.shouldShow(null, false));
        }

        function test_history_exclusions_match_app_id_or_app_name() {
            const excludedApps = ["org.example.Chat", "Quiet Sender"];
            const byDesktopEntry = {desktopEntry: "org.example.Chat", appName: "Chat"};
            const byAppName = {desktopEntry: "", appName: "Quiet Sender"};
            const tagged = {desktopEntry: "", appName: "nohistory"};
            const normal = {desktopEntry: "org.example.Mail", appName: "Mail"};

            verify(HistoryPolicy.isExcluded(byDesktopEntry, excludedApps));
            verify(HistoryPolicy.isExcluded(byAppName, excludedApps));
            verify(HistoryPolicy.isExcluded(tagged, excludedApps));
            verify(!HistoryPolicy.isExcluded(normal, excludedApps));
            compare(HistoryPolicy.visibleNotifications(
                [byDesktopEntry, byAppName, tagged, normal], excludedApps), [normal]);
            verify(ToastPolicy.shouldShow(tagged, false));
        }

        function test_critical_history_colors() {
            const note = notification(1, [action("default", "Open")]);
            card = createTemporaryObject(cardComponent, host, {
                "width": 340,
                "config": config,
                "critical": true,
                "appIconSource": "data:image/svg+xml," + encodeURIComponent(
                    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="black"/></svg>'),
                "timeLabel": "12:34",
                "notification": note,
                "actionEntries": Model.actionsFor(note.actions)
            });
            waitForPolish(host.Window.window);
            const icon = findText(card, "󰀧");
            verify(icon !== null);
            compare(icon.color, card.criticalBorderColor);
            verify(!findChild(card, "historyAppIcon").visible);
            compare(card.border.color, card.criticalBorderColor);
            for (const label of ["12:34", note.summary, note.body]) compare(findText(card, label).color, card.criticalTextColor)
            card.selected = true;
            waitForPolish(host.Window.window);
            compare(card.border.color, card.criticalBorderColor);
            compare(findText(card, "[o] Open").color, card.criticalTextColor);
        }

        function test_history_rows_have_subtle_card_surfaces() {
            const note = notification(1);
            card = createTemporaryObject(cardComponent, host, {width: 340, config: config,
                notification: note});
            compare(card.color, config.bg);
            compare(card.border.width, 1);
            compare(card.border.color, config.muted);
            compare(card.opacity, 1);
            const hover = findChild(card, "historyHoverHandler");
            verify(hover !== null);
            mouseMove(card, card.width / 2, card.height / 2);
            tryVerify(() => hover.hovered);
            compare(card.color, config.bg);
            compare(card.opacity, 1);
            compare(card.border.color, config.selectionBackground);
            mouseMove(host, host.width - 1, host.height - 1);
            tryVerify(() => !hover.hovered);
            compare(card.opacity, 1);
            compare(card.border.color, config.muted);
            // Assert selected treatment directly; hover itself is driven by
            // HoverHandler in the actual UI.
            card.selected = true;
            compare(card.color, config.bg);
            compare(card.border.color, config.selectionBackground);
            compare(findText(card, note.summary).color, config.fg);
        }

        function test_actionless_notification_has_no_button_row() {
            const note = notification(1);
            card = createTemporaryObject(cardComponent, host, {
                "width": 340,
                "config": config,
                "selected": true,
                "notification": note,
                "actionEntries": Model.actionsFor(note.actions)
            });
            waitForPolish(host.Window.window);
            compare(findText(card, "[c] Close"), null);
            compare(findChild(card, "historyCloseButton"), null);
        }

        function test_history_photo_does_not_expand_card() {
            const note = notification(1);
            note.image = "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900"><rect width="1600" height="900" fill="orange"/></svg>');
            card = createTemporaryObject(cardComponent, host, {
                "width": 340,
                "config": config,
                "selected": true,
                "notification": note
            });
            waitForPolish(host.Window.window);
            compare(findChild(card, "historyImagePreview"), null);
            verify(card.implicitHeight < 100);
        }

        function test_long_body_can_expand() {
            const note = notification(1);
            note.body = "This message should expand and reveal its extra wrapped lines. ".repeat(4);
            card = createTemporaryObject(cardComponent, host, {
                width: 340, height: 120, config: config, notification: note
            });
            verify(card !== null);
            waitForPolish(host.Window.window);
            const body = findChild(card, "historyBodyText");
            const hint = findChild(card, "historyExpandHint");
            verify(body.truncated);
            verify(hint.visible);
            compare(hint.opacity, 0.5);
            const collapsedHeight = card.implicitHeight;

            card.selected = true;
            compare(hint.color, config.selectionBackground);
            compare(hint.opacity, 1);
            card.expandRequested.connect(() => card.expanded = !card.expanded);
            mouseClick(card, card.width / 2, 12);
            verify(card.expanded);
            waitForPolish(host.Window.window);
            compare(body.truncated, false);
            verify(card.implicitHeight > collapsedHeight);
            compare(hint.text, "󰅃");

            mouseClick(card, card.width / 2, 12);
            verify(!card.expanded);
        }

        function test_card_actions_without_per_item_close_button() {
            const note = notification(1, [action("default", "Open")]);
            card = createTemporaryObject(cardComponent, host, {
                "width": 340,
                "config": config,
                "selected": true,
                "notification": note,
                "actionEntries": Model.actionsFor(note.actions)
            });
            card.actionRequested.connect((entry) => {
                return entry.action ? entry.action.invoke() : closes++;
            });
            waitForPolish(host.Window.window);
            const button = findChild(card, "historyAction-o");
            mouseClick(button, button.width / 2, button.height / 2);
            compare(service.calls, ["action:default"]);
            compare(findChild(card, "historyCloseButton"), null);
        }

        name: "NotificationHistory"
        when: windowShown
    }

}
