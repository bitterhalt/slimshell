import QtQuick
import QtTest
import "../../components"

Item {
    id: host

    width: 500
    height: 100

    QtObject {
        id: fixtureConfig
    }

    QtObject {
        id: fixtureWindow

        property int height: 32
    }

    Component {
        id: revealerComponent

        ItemRevealer {
            config: fixtureConfig
            barWindow: fixtureWindow

            Text {
                text: "12:34"
                font.pointSize: 12
            }

            revealData: [
                Text {
                    text: "Thursday"
                    font.pointSize: 12
                }
            ]
        }
    }

    Component {
        id: reverseRevealerComponent

        ItemRevealer {
            config: fixtureConfig
            barWindow: fixtureWindow
            revealToLeft: true

            Rectangle {
                objectName: "reversePrimary"

                width: 30
                height: 20
                color: "#333"
            }

            revealData: [
                Rectangle {
                    objectName: "reverseRevealed"

                    width: 40
                    height: 20
                    color: "#888"
                }
            ]
        }
    }

    TestCase {
        name: "ItemRevealer"
        when: windowShown

        property var revealer: null

        function init() {
            revealer = createTemporaryObject(revealerComponent, host, {
                x: 0,
                y: 20
            });
            verify(revealer !== null);
            compare(revealer.revealProgress, 0);
        }

        function test_primary_content_sets_width() {
            verify(revealer.width >= 20);
        }

        function test_reveals_on_hover_and_collapses() {
            const collapsedWidth = revealer.width;

            verify(collapsedWidth > 0);
            mouseMove(revealer, 4, revealer.height / 2);
            tryCompare(revealer, "revealProgress", 1);
            verify(revealer.width > collapsedWidth);
            verify(revealer.revealExtent > 0);

            mouseMove(host, host.width - 1, host.height - 1);
            tryCompare(revealer, "revealProgress", 0);
            compare(revealer.width, collapsedWidth);
        }

        function test_reverse_layout_keeps_primary_on_the_right() {
            const reverse = createTemporaryObject(reverseRevealerComponent, host, {
                x: 200,
                y: 20
            });
            verify(reverse !== null);
            const primary = findChild(reverse, "reversePrimary");
            const revealed = findChild(reverse, "reverseRevealed");
            verify(primary !== null);
            verify(revealed !== null);
            compare(reverse.width, 30);
            compare(primary.mapToItem(reverse, 0, 0).x, 0);

            mouseMove(reverse, reverse.width - 4, reverse.height / 2);
            tryCompare(reverse, "revealProgress", 1);

            compare(reverse.width, 30 + 8 + 40);
            const primaryX = primary.mapToItem(reverse, 0, 0).x;
            compare(primaryX, reverse.width - 30);
            compare(revealed.mapToItem(reverse, 0, 0).x + revealed.width, primaryX - 8);
        }

        function test_reveal_lock_keeps_content_open() {
            mouseMove(revealer, 4, revealer.height / 2);
            tryCompare(revealer, "revealProgress", 1);

            revealer.revealLocked = true;
            mouseMove(host, host.width - 1, host.height - 1);
            tryVerify(() => !revealer.hovered);
            compare(revealer.revealProgress, 1);

            revealer.revealLocked = false;
            tryCompare(revealer, "revealProgress", 0);
        }
    }
}
