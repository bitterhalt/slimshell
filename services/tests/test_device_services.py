"""Shared audio/network services tested without PipeWire or NetworkManager."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]

TEST = r'''
import QtQuick
import QtTest
import "."
Item {
    id: host
    Component { id: audio; AudioService {} }
    Component { id: network; NetworkService {} }
    Component { id: fixtureComponent; AudioFixture {} }
    TestCase {
        name: "SharedDeviceServices"
        property var fixture: null
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop/);
            fixture = createTemporaryObject(fixtureComponent, host);
            Pipewire.nodes = {values: fixture.allNodes};
            Pipewire.defaultAudioSink = fixture.speaker;
            Pipewire.defaultAudioSource = fixture.mic;
            Pipewire.preferredDefaultAudioSink = null;
            Pipewire.preferredDefaultAudioSource = null;
            Networking.devices = {values: []};
            Networking.wifiEnabled = true;
            Networking.wifiHardwareEnabled = true;
        }
        function test_audio_tracks_defaults_once_and_builds_shared_rows() {
            const service = createTemporaryObject(audio, host, {config: fixture.config});
            compare(service.trackedNodes.length, 4);
            compare(service.outputRows.length, 2);
            compare(service.inputRows.length, 1);
            compare(service.streamRows.length, 1);
            compare(service.volume, 50);
            const tracker = Array.from(service.data).find(child => child.objects !== undefined);
            compare(tracker.objects.length, 4);
        }
        function test_audio_changes_are_visible_to_all_consumers() {
            const service = createTemporaryObject(audio, host, {config: fixture.config});
            service.setVolume(1, 9);
            compare(fixture.speakerAudio.volume, 1.1);
            compare(service.volume, 110);
            service.adjustVolume(1, -0.1);
            compare(service.volume, 100);
            service.toggleMute(1);
            verify(service.muted);
            service.setOutput(2);
            compare(Pipewire.preferredDefaultAudioSink, fixture.headset);
            service.setInput(3);
            compare(Pipewire.preferredDefaultAudioSource, fixture.mic);
            service.setVolume(1, NaN);
            compare(service.volume, 100);
            service.setOutput(3);
            compare(Pipewire.preferredDefaultAudioSink, fixture.headset);
        }
        function test_network_selects_connected_adapter_and_strongest_ssid() {
            const weak = {name: "home", connected: false, signalStrength: 0.2};
            const strong = {name: "home", connected: true, signalStrength: 0.8};
            const unused = {type: DeviceType.Wifi, connected: false, networks: {values: []}};
            const wifi = {type: DeviceType.Wifi, connected: true,
                networks: {values: [weak, strong]}};
            Networking.devices = {values: [unused, wifi]};
            const service = createTemporaryObject(network, host);
            compare(service.wifiDevice, wifi);
            compare(service.connectedWifi, strong);
            compare(service.networkForSsid("home"), strong);
            compare(service.networkRows.length, 1);
            compare(service.connectionKind, "wifi");
            verify(service.wifiBrowsingAvailable);
            const wired = {type: DeviceType.Wired, connected: true};
            Networking.devices = {values: [unused, wifi, wired]};
            compare(service.connectionKind, "ethernet");
            verify(!service.wifiBrowsingAvailable);
            Networking.devices = {values: []};
            compare(service.wifiDevice, null);
            compare(service.networkRows.length, 0);
            compare(service.connectionKind, "disconnected");
        }
    }
}
'''


class DeviceServiceTests(unittest.TestCase):
    def test_shared_device_backends(self):
        with tempfile.TemporaryDirectory(prefix="device-services-") as directory:
            base = Path(directory)
            for name, feature in (("AudioService", "audio"), ("NetworkService", "network")):
                source = (ROOT / "services" / f"{name}.qml").read_text()
                source = "\n".join(line for line in source.splitlines()
                                   if not line.startswith("import Quickshell"))
                source = source.replace(f'"../bar/modules/{feature}/Model.js"',
                                        f'"{feature}Model.js"')
                (base / f"{name}.qml").write_text('import "."\n' + source)
                (base / f"{feature}Model.js").write_text(
                    (ROOT / "bar" / "modules" / feature / "Model.js").read_text()
                )
            fixture = (ROOT / "bar/modules/audio/tests/AudioFixture.qml").read_text()
            (base / "AudioFixture.qml").write_text(
                fixture.replace('"../Model.js"', '"audioModel.js"')
            )
            (base / "qmldir").write_text(
                "singleton Pipewire 1.0 Pipewire.qml\n"
                "singleton Networking 1.0 Networking.qml\n"
                "DeviceType 1.0 DeviceType.qml\n"
            )
            (base / "Pipewire.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var nodes: ({values: []})
    property var defaultAudioSink: null
    property var defaultAudioSource: null
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
}
''')
            (base / "Networking.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var devices: ({values: []})
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
}
''')
            (base / "DeviceType.qml").write_text(
                "import QtQuick\nQtObject { enum Type { Wifi, Wired } }\n"
            )
            (base / "PwObjectTracker.qml").write_text(
                "import QtQuick\nQtObject { property var objects: [] }\n"
            )
            (base / "tst_devices.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
