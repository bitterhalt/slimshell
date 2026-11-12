import QtQuick
import QtTest
import "../components"
import "."

Item {
    id: host
    width: 500
    height: 40

    ControlConfig {
        id: fixtureConfig
    }

    QtObject {
        id: fakeBar
        property int height: 30
    }

    QtObject {
        id: fakeService
        property var volumes: []
        property bool compact: false
        property string busyPath: ""
        property string errorText: ""
        property string inventoryError: ""
        property var activated: []
        property var unmounted: []
        function activate(volume) {
            activated = activated.concat([volume.path]);
        }
        function unmount(path) {
            unmounted = unmounted.concat([path]);
        }
    }

    Drives {
        id: drives
        config: fixtureConfig
        barWindow: fakeBar
        driveService: fakeService
    }

    TestCase {
        name: "DrivesBar"
        when: windowShown

        function volume(path, options) {
            var node = {
                path: path,
                label: "Volume",
                size: "16.0 GB",
                free: "8.0 GB",
                fstype: "ext4",
                mounted: false,
                mountpoint: "",
                locked: false,
                loop: false
            };
            var overrides = options || {};
            for (var key in overrides)
                node[key] = overrides[key];
            return node;
        }

        function manyVolumes(count) {
            var list = [];
            for (var i = 0; i < count; i++)
                list.push(volume("/dev/disk" + i + "p1"));
            return list;
        }

        function chip(path) {
            return findChild(drives, "driveChip/" + path);
        }

        function glyph(path) {
            return findChild(drives, "driveGlyph/" + path);
        }

        function tooltip(path) {
            const item = chip(path);
            if (!item)
                return null;
            const resources = item.resources || [];
            for (let i = 0; i < resources.length; i++) {
                if (resources[i].objectName === "driveTooltip/" + path)
                    return resources[i];
            }
            return null;
        }

        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            fakeService.volumes = [];
            fakeService.compact = false;
            fakeService.busyPath = "";
            fakeService.errorText = "";
            fakeService.inventoryError = "";
            fakeService.activated = [];
            fakeService.unmounted = [];
            mouseMove(host, host.width - 1, host.height - 1);
            wait(50);
        }

        function test_hidden_without_volumes() {
            verify(!drives.visible);
            compare(drives.implicitWidth, 0);
            fakeService.volumes = [volume("/dev/sdb1")];
            wait(50);
            verify(drives.visible);
            verify(drives.implicitWidth > 0);
        }

        function test_glyphs_and_mount_state() {
            fakeService.volumes = [volume("/dev/sdb1", {
                    mounted: true,
                    mountpoint: "/run/media/user/STICK"
                }), volume("/dev/sdc1"), volume("/dev/sdd1", {
                    locked: true,
                    fstype: "crypto_LUKS"
                }), volume("/dev/loop0", {
                    loop: true
                })];
            wait(50);
            compare(glyph("/dev/sdb1").text, "󱊞");
            compare(glyph("/dev/sdc1").text, "󱊞");
            compare(glyph("/dev/sdd1").text, "󰌾");
            compare(glyph("/dev/loop0").text, "󰗮");
            compare(glyph("/dev/sdb1").color, fixtureConfig.fg);
            compare(glyph("/dev/sdc1").color, fixtureConfig.muted);
            compare(glyph("/dev/sdd1").color, fixtureConfig.muted);
        }

        function test_busy_chip_is_dimmed() {
            fakeService.volumes = [volume("/dev/sdb1", {
                    mounted: true
                })];
            fakeService.busyPath = "/dev/sdb1";
            wait(50);
            compare(glyph("/dev/sdb1").opacity, 0.45);
        }

        function test_click_opens_mounted_and_mounts_unmounted() {
            fakeService.volumes = [volume("/dev/sdb1", {
                    mounted: true,
                    mountpoint: "/run/media/user/STICK"
                }), volume("/dev/sdc1")];
            wait(50);
            const mounted = chip("/dev/sdb1");
            const unmounted = chip("/dev/sdc1");
            mouseClick(mounted, mounted.width / 2, mounted.height / 2, Qt.LeftButton);
            compare(fakeService.activated, ["/dev/sdb1"]);
            mouseClick(unmounted, unmounted.width / 2, unmounted.height / 2, Qt.LeftButton);
            compare(fakeService.activated, ["/dev/sdb1", "/dev/sdc1"]);
        }

        function test_right_click_unmounts_only_mounted_volumes() {
            fakeService.volumes = [volume("/dev/sdb1", {
                    mounted: true,
                    mountpoint: "/run/media/user/STICK"
                }), volume("/dev/sdc1")];
            wait(50);
            const mounted = chip("/dev/sdb1");
            const unmounted = chip("/dev/sdc1");
            mouseClick(mounted, mounted.width / 2, mounted.height / 2, Qt.RightButton);
            compare(fakeService.unmounted, ["/dev/sdb1"]);
            mouseClick(unmounted, unmounted.width / 2, unmounted.height / 2, Qt.RightButton);
            compare(fakeService.unmounted, ["/dev/sdb1"]);
        }

        function test_locked_volume_is_inert() {
            fakeService.volumes = [volume("/dev/sdd1", {
                    locked: true,
                    fstype: "crypto_LUKS"
                })];
            wait(50);
            const locked = chip("/dev/sdd1");
            mouseClick(locked, locked.width / 2, locked.height / 2, Qt.LeftButton);
            mouseClick(locked, locked.width / 2, locked.height / 2, Qt.RightButton);
            compare(fakeService.activated, []);
            compare(fakeService.unmounted, []);
        }

        function test_compact_chip_counts_and_expands() {
            fakeService.volumes = manyVolumes(5);
            fakeService.compact = true;
            wait(50);
            const compact = findChild(drives, "driveCompactChip");
            verify(compact.visible);
            compare(chip("/dev/disk0p1"), null);
            const tooltip = compact.resources.find(resource => resource.objectName === "driveCompactTooltip");
            verify(tooltip.text.includes("5 removable volumes"));
            verify(tooltip.text.includes("mounted\nclick to expand"));
            mouseClick(compact, compact.width / 2, compact.height / 2, Qt.LeftButton);
            verify(!fakeService.compact);
            wait(50);
            verify(chip("/dev/disk0p1") !== null);
            verify(!compact.visible);
        }

        function test_tooltips_describe_actions_and_errors() {
            fakeService.volumes = [volume("/dev/sdb1", {
                    mounted: true,
                    mountpoint: "/run/media/user/STICK"
                }), volume("/dev/sdc1"), volume("/dev/sde1", {
                    label: "STICK",
                    mounted: true,
                    mountpoint: "/run/media/user/STICK"
                })];
            wait(50);
            const mountedTip = tooltip("/dev/sdb1");
            verify(mountedTip.text.includes("mounted at /run/media/user/STICK"));
            verify(mountedTip.text.includes("(8.0 GB free)\nclick to open"));
            verify(mountedTip.text.includes("right-click to unmount"));
            const sameNameTip = tooltip("/dev/sde1");
            verify(sameNameTip.text.includes("— mounted (8.0 GB free)\nclick to open"));
            verify(!sameNameTip.text.includes("/run/media/user/STICK"));
            verify(tooltip("/dev/sdc1").text.includes("\nclick to mount and open"));
            fakeService.errorText = "Access denied";
            compare(tooltip("/dev/sdb1").text, "Drive bay: Access denied");
            fakeService.errorText = "";
            fakeService.inventoryError = "lsblk failed";
            compare(tooltip("/dev/sdb1").text, "Drive bay: lsblk failed");
        }
    }
}
