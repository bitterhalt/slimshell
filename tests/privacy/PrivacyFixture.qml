import QtQuick
import QtTest
import "../components"
import "Model.js" as Model
import "."

Item {
    id: host
    width: 400
    height: 100
    ControlConfig {
        id: fixtureConfig
        fg: "#dddddd"
        selectionBackground: "#aa7755"
        selectionForeground: "#111111"
        iconSize: 12
    }
    QtObject {
        id: fixtureBar
        property int height: 30
    }
    QtObject {
        id: privacy
        property bool microphoneActive: false
        property var microphoneApplications: []
    }
    QtObject {
        id: recorder
        property bool runningNow: false
        property int stops: 0
        function stop() {
            stops++;
        }
    }
    Privacy {
        id: indicator
        config: fixtureConfig
        barWindow: fixtureBar
        privacyService: privacy
        recorderService: recorder
    }
    TestCase {
        name: "PrivacyIndicator"
        when: windowShown

        function capture(name, overrides) {
            const source = {
                id: 1,
                audio: {},
                isStream: false,
                isSink: false,
                properties: {}
            };
            const target = {
                id: 2,
                audio: {},
                isStream: true,
                properties: {
                    "media.class": "Stream/Input/Audio",
                    "application.name": name
                }
            };
            return Object.assign({
                source: source,
                target: target,
                state: "active"
            }, overrides || {});
        }
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            privacy.microphoneActive = false;
            privacy.microphoneApplications = [];
            recorder.runningNow = false;
            recorder.stops = 0;
            mouseMove(host, host.width - 1, host.height - 1);
        }
        function test_active_capture_and_application_names() {
            compare(Model.microphoneApplications([capture("Browser"), capture("Browser"), capture("Chat")], "active"), ["Browser", "Chat"]);
        }
        function test_ignores_paused_playback_and_monitor_streams() {
            const paused = capture("Paused", {
                state: "paused"
            });
            const playback = capture("Playback");
            playback.target.properties["media.class"] = "Stream/Output/Audio";
            const monitor = capture("Visualizer");
            monitor.target.properties["stream.monitor"] = "true";
            const sinkMonitor = capture("Output monitor");
            sinkMonitor.source.isSink = true;
            const namedMonitor = capture("Named monitor");
            namedMonitor.source.name = "output.monitor";
            compare(Model.microphoneApplications([paused, playback, monitor, sinkMonitor, namedMonitor, null], "active"), []);
        }
        function test_missing_nodes_and_properties_are_safe() {
            const incomplete = capture("Incomplete");
            incomplete.target.properties = {};
            compare(Model.microphoneApplications([incomplete, capture("Gone", {
                    source: null
                }), capture("Gone", {
                    target: null
                })], "active"), []);
        }
        function test_muted_mic_is_still_in_use_and_name_fallback() {
            const group = capture("Chat");
            group.source.audio.muted = true;
            delete group.target.properties["application.name"];
            group.target.properties["application.process.binary"] = "chat";
            compare(Model.microphoneApplications([group], "active"), ["chat"]);
        }
        function test_recording_blinks_without_hiding_click_target() {
            recorder.runningNow = true;
            const recording = findChild(indicator, "recordingPrivacyIndicator");
            const glyph = findChild(indicator, "recordingPrivacyGlyph");
            tryVerify(() => glyph.opacity < 0.1, 1500);
            verify(recording.visible);
            compare(recording.opacity, 1);
            mouseClick(recording, recording.width / 2, recording.height / 2);
            compare(recorder.stops, 1);
            recorder.runningNow = false;
            compare(glyph.opacity, 1);
        }

        function test_hidden_when_idle_and_separate_activity() {
            verify(!indicator.visible);
            privacy.microphoneApplications = ["Chat"];
            privacy.microphoneActive = true;
            verify(indicator.visible);
            const mic = findChild(indicator, "microphonePrivacyIndicator");
            const recording = findChild(indicator, "recordingPrivacyIndicator");
            verify(mic.visible);
            verify(!recording.visible);
            compare(findChild(indicator, "privacyPill").color, Qt.alpha(fixtureConfig.selectionBackground, 0.12));
            verify(mic.description.includes("Chat"));
            mouseClick(mic, mic.width / 2, mic.height / 2);
            compare(recorder.stops, 0);
            recorder.runningNow = true;
            verify(recording.visible);
            tryVerify(() => recording.x >= mic.width);
            compare(mic.parent, recording.parent);
            compare(findChild(indicator, "recordingPrivacyGlyph").color, fixtureConfig.selectionBackground);
            compare(findChild(indicator, "microphonePrivacyGlyph").color, fixtureConfig.fg);
            mouseClick(recording, recording.width / 2, recording.height / 2);
            compare(recorder.stops, 1);
            recorder.runningNow = false;
            verify(indicator.visible);
            privacy.microphoneActive = false;
            verify(!indicator.visible);
        }
    }
}
