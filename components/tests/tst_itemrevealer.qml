import QtQuick
import QtTest
import ".."

Item {
    id: host

    width: 500
    height: 100

    QtObject {
        id: fixtureConfig

        property int barModuleSpacing: 8
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
    }
}
