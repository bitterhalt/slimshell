import QtQuick
import QtTest
import "../../services/drives/DriveModel.js" as Model

TestCase {
    name: "DriveModel"

    function snapshot(blockdevices) {
        return JSON.stringify({
            blockdevices: blockdevices
        });
    }

    function usbDisk(children) {
        return {
            name: "sdb",
            path: "/dev/sdb",
            size: 32000000000,
            type: "disk",
            fstype: "",
            label: null,
            rm: true,
            hotplug: true,
            tran: "usb",
            model: "USB Stick",
            children: children || []
        };
    }

    function test_lists_removable_usb_volumes_and_ignores_internal_disks() {
        const volumes = Model.parseLsblk(snapshot([usbDisk([
                {
                    name: "sdb1",
                    path: "/dev/sdb1",
                    size: 31999000000,
                    type: "part",
                    fstype: "vfat",
                    label: "STICK",
                    mountpoints: ["/run/media/user/STICK"],
                    rm: true,
                    hotplug: true,
                    fsavail: 12345678901,
                    children: []
                }
            ]),
            {
                name: "nvme0n1",
                path: "/dev/nvme0n1",
                size: 1000000000000,
                type: "disk",
                fstype: "",
                rm: false,
                hotplug: false,
                tran: "nvme",
                children: [
                    {
                        name: "nvme0n1p2",
                        path: "/dev/nvme0n1p2",
                        size: 900000000000,
                        type: "part",
                        fstype: "ext4",
                        label: "root",
                        mountpoints: ["/"],
                        children: []
                    }
                ]
            }
        ]));
        compare(volumes.length, 1);
        compare(volumes[0].path, "/dev/sdb1");
        compare(volumes[0].diskPath, "/dev/sdb");
        compare(volumes[0].label, "STICK");
        compare(volumes[0].fstype, "vfat");
        verify(volumes[0].mounted);
        compare(volumes[0].mountpoint, "/run/media/user/STICK");
        compare(volumes[0].size, "32.0 GB");
        compare(volumes[0].free, "12.3 GB");
        verify(!volumes[0].locked);
        verify(!volumes[0].loop);
    }

    function test_shows_loop_images_and_superfloppy_devices() {
        const volumes = Model.parseLsblk(snapshot([
            {
                name: "loop0",
                path: "/dev/loop0",
                size: 530000000,
                type: "loop",
                fstype: "squashfs",
                label: "Image",
                mountpoints: ["/snap/image"],
                rm: false,
                hotplug: false,
                children: []
            },
            {
                name: "sdc",
                path: "/dev/sdc",
                size: 8000000000,
                type: "disk",
                fstype: "exfat",
                label: "CARD",
                mountpoints: [null],
                rm: true,
                hotplug: true,
                tran: "usb",
                children: []
            }
        ]));
        compare(volumes.length, 2);
        compare(volumes[0].path, "/dev/loop0");
        verify(volumes[0].loop);
        verify(volumes[0].mounted);
        compare(volumes[1].path, "/dev/sdc");
        verify(!volumes[1].mounted);
    }

    function test_unlocked_luks_children_are_listed_and_locked_volumes_are_inert() {
        const unlocked = Model.parseLsblk(snapshot([usbDisk([
                {
                    name: "sdb1",
                    path: "/dev/sdb1",
                    size: 31999000000,
                    type: "part",
                    fstype: "crypto_LUKS",
                    label: "VAULT",
                    mountpoints: [],
                    children: [
                        {
                            name: "vault",
                            path: "/dev/mapper/vault",
                            size: 31990000000,
                            type: "crypt",
                            fstype: "ext4",
                            label: "VAULT",
                            mountpoints: ["/run/media/user/VAULT"],
                            children: []
                        }
                    ]
                }
            ])]));
        compare(unlocked.length, 1);
        compare(unlocked[0].path, "/dev/mapper/vault");
        verify(unlocked[0].mounted);
        verify(!unlocked[0].locked);

        const locked = Model.parseLsblk(snapshot([usbDisk([
                {
                    name: "sdb2",
                    path: "/dev/sdb2",
                    size: 12000000000,
                    type: "part",
                    fstype: "crypto_LUKS",
                    label: "SECRET",
                    mountpoints: [],
                    children: []
                }
            ])]));
        compare(locked.length, 1);
        verify(locked[0].locked);
        verify(!locked[0].mounted);
    }

    function test_swap_zram_and_invalid_payloads_are_ignored() {
        compare(Model.parseLsblk(snapshot([
            {
                name: "sdb",
                path: "/dev/sdb",
                type: "disk",
                rm: true,
                children: [
                    {
                        name: "sdb1",
                        path: "/dev/sdb1",
                        type: "part",
                        fstype: "swap",
                        mountpoints: [],
                        children: []
                    }
                ]
            }
        ])), []);
        compare(Model.parseLsblk(snapshot([
            {
                name: "zram0",
                path: "/dev/zram0",
                type: "disk",
                rm: true,
                hotplug: true,
                children: []
            }
        ])), []);
        compare(Model.parseLsblkResult("not json").valid, false);
        compare(Model.parseLsblkResult("{}").valid, false);
        compare(Model.parseLsblkResult(snapshot([])).valid, true);
    }

    function test_isohybrid_live_media_keeps_iso_and_hides_efi() {
        const volumes = Model.parseLsblk(snapshot([usbDisk([
                {
                    name: "sdb1",
                    path: "/dev/sdb1",
                    size: 1078804480,
                    type: "part",
                    fstype: "iso9660",
                    label: "VOID_LIVE",
                    parttype: "0x0",
                    parttypename: "Empty",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb2",
                    path: "/dev/sdb2",
                    size: 33554432,
                    type: "part",
                    fstype: "vfat",
                    label: "grub_uefi",
                    parttype: "0xef",
                    parttypename: "EFI (FAT-12/16/32)",
                    mountpoints: [],
                    children: []
                }
            ])]));
        compare(volumes.length, 1);
        compare(volumes[0].path, "/dev/sdb1");
        compare(volumes[0].label, "VOID_LIVE");
    }

    function test_udisks_ignored_partition_types_are_hidden() {
        const volumes = Model.parseLsblk(snapshot([usbDisk([
                {
                    name: "sdb1",
                    path: "/dev/sdb1",
                    type: "part",
                    fstype: "vfat",
                    label: "ESP",
                    parttype: "c12a7328-f81f-11d2-ba4b-00a0c93ec93b",
                    parttypename: "EFI System",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb2",
                    path: "/dev/sdb2",
                    type: "part",
                    fstype: "vfat",
                    label: "XBOOT",
                    parttype: "bc13c2ff-59e6-4262-a352-b275fd6f7172",
                    parttypename: "Extended Boot Loader",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb3",
                    path: "/dev/sdb3",
                    type: "part",
                    fstype: "ntfs",
                    label: "WINRE",
                    parttype: "de94bba4-06d1-4d40-a16a-bfd50179d6ac",
                    parttypename: "Windows recovery environment",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb4",
                    path: "/dev/sdb4",
                    type: "part",
                    fstype: "LVM2_member",
                    label: "pool",
                    parttype: "e6d6d379-f507-44c2-a23c-238f2a3df928",
                    parttypename: "Linux LVM",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb5",
                    path: "/dev/sdb5",
                    type: "part",
                    fstype: "exfat",
                    label: "DATA",
                    parttype: "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7",
                    parttypename: "Microsoft basic data",
                    mountpoints: [],
                    children: []
                }
            ])]));
        compare(volumes.length, 1);
        compare(volumes[0].path, "/dev/sdb5");
        compare(volumes[0].label, "DATA");
    }

    function test_recovery_labels_are_hidden_for_ntfs_and_vfat_only() {
        const volumes = Model.parseLsblk(snapshot([usbDisk([
                {
                    name: "sdb1",
                    path: "/dev/sdb1",
                    type: "part",
                    fstype: "ntfs",
                    label: "Recovery",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb2",
                    path: "/dev/sdb2",
                    type: "part",
                    fstype: "vfat",
                    label: "SYSTEM_RESERVED",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb3",
                    path: "/dev/sdb3",
                    type: "part",
                    fstype: "ext4",
                    label: "Recovery",
                    mountpoints: [],
                    children: []
                },
                {
                    name: "sdb4",
                    path: "/dev/sdb4",
                    type: "part",
                    fstype: "vfat",
                    label: "ELECTRONICS",
                    mountpoints: [],
                    children: []
                }
            ])]));
        compare(volumes.length, 2);
        compare(volumes[0].path, "/dev/sdb3");
        compare(volumes[1].path, "/dev/sdb4");
    }

    function test_older_single_mountpoint_field_is_supported() {
        const volumes = Model.parseLsblk(snapshot([
            {
                name: "sdb",
                path: "/dev/sdb",
                type: "disk",
                rm: true,
                children: [
                    {
                        name: "sdb1",
                        path: "/dev/sdb1",
                        type: "part",
                        fstype: "ext4",
                        label: "OLD",
                        mountpoint: "/mnt/old",
                        children: []
                    }
                ]
            }
        ]));
        compare(volumes.length, 1);
        verify(volumes[0].mounted);
        compare(volumes[0].mountpoint, "/mnt/old");
    }

    function test_commands_validate_device_and_mount_paths() {
        compare(Model.mountCommand("/dev/sdb1"), ["udisksctl", "mount", "-b", "/dev/sdb1", "--no-user-interaction"]);
        compare(Model.unmountCommand("/dev/sdb1"), ["udisksctl", "unmount", "-b", "/dev/sdb1", "--no-user-interaction"]);
        compare(Model.powerOffCommand("/dev/sdb"), ["udisksctl", "power-off", "-b", "/dev/sdb", "--no-user-interaction"]);
        compare(Model.openCommand("/run/media/user/STICK"), ["xdg-open", "/run/media/user/STICK"]);
        compare(Model.mountpointCommand("/dev/sdb1"), ["lsblk", "-n", "-o", "MOUNTPOINTS", "/dev/sdb1"]);
        compare(Model.mountpointCommand("sdb1"), []);
        compare(Model.mountpointCommand("/etc/passwd"), []);
        compare(Model.mountCommand("sdb1"), []);
        compare(Model.mountCommand("/etc/passwd"), []);
        compare(Model.openCommand("relative/path"), []);
        compare(Model.openCommand(""), []);
        compare(Model.monitorCommand(), ["udisksctl", "monitor"]);
        verify(Model.lsblkCommand().includes("-J"));
        verify(Model.lsblkCommand().join(" ").includes("PARTTYPE,PARTTYPENAME"));
    }

    function test_mountpoint_name_ignores_trailing_slash() {
        compare(Model.mountpointName("/run/media/bazz/Ventoy"), "Ventoy");
        compare(Model.mountpointName("/run/media/bazz/Ventoy/"), "Ventoy");
        compare(Model.mountpointName("/mnt"), "mnt");
        compare(Model.mountpointName(""), "");
        compare(Model.mountpointName(null), "");
    }

    function test_first_mountpoint_skips_blank_and_relative_lines() {
        compare(Model.firstMountpoint("/run/media/user/STICK\n"), "/run/media/user/STICK");
        compare(Model.firstMountpoint("\n  \n/boot/efi\n/media/data\n"), "/boot/efi");
        compare(Model.firstMountpoint(" relative\n"), "");
        compare(Model.firstMountpoint("/"), "");
        compare(Model.firstMountpoint(""), "");
        compare(Model.firstMountpoint(null), "");
    }

    function test_event_lines_ignore_banners() {
        verify(Model.isEventLine("20:14:03.031: Device /dev/sdb1 mounted at /run/media/user/STICK"));
        verify(Model.isEventLine("  Mounted /dev/sdb1 at /run/media/user/STICK"));
        verify(!Model.isEventLine("Monitoring the udisks daemon. Press Ctrl+C to exit."));
        verify(!Model.isEventLine("The udisks-daemon is running (pid=1234)."));
        verify(!Model.isEventLine(""));
    }

    function test_size_formatting() {
        compare(Model.formatSize(0), "");
        compare(Model.formatSize(-1), "");
        compare(Model.formatSize(512), "1 kB");
        compare(Model.formatSize(1000000), "1 MB");
        compare(Model.formatSize(1500000000), "1.5 GB");
        compare(Model.formatSize(2000000000000), "2.0 TB");
    }

    function test_tooltips_describe_the_available_actions() {
        const mounted = {
            label: "STICK",
            size: "32.0 GB",
            free: "12.3 GB",
            mounted: true,
            mountpoint: "/run/media/user/STICK",
            locked: false
        };
        compare(Model.tooltip(mounted, ""), "STICK · 32.0 GB — mounted (12.3 GB free)\nclick to open · right-click to unmount");
        compare(Model.tooltip({
            label: "USB Stick",
            size: "32.0 GB",
            free: "12.3 GB",
            mounted: true,
            mountpoint: "/run/media/user/1234-ABCD",
            locked: false
        }, ""), "USB Stick · 32.0 GB — mounted at /run/media/user/1234-ABCD (12.3 GB free)\nclick to open · right-click to unmount");
        compare(Model.tooltip({
            label: "STICK",
            size: "32.0 GB",
            free: "",
            mounted: false,
            mountpoint: "",
            locked: false
        }, ""), "STICK · 32.0 GB\nclick to mount and open");
        compare(Model.tooltip({
            label: "SECRET",
            size: "12.0 GB",
            mounted: false,
            mountpoint: "",
            locked: true
        }, ""), "SECRET · 12.0 GB — locked (unlock via terminal)");
        compare(Model.tooltip(mounted, "Access denied"), "Drive bay: Access denied");
        compare(Model.tooltip(null, ""), "");
    }

    function test_compact_staging_has_hysteresis() {
        verify(!Model.nextCompactStage(false, 4));
        verify(Model.nextCompactStage(false, 5));
        verify(Model.nextCompactStage(true, 4));
        verify(!Model.nextCompactStage(true, 3));
        compare(Model.compactTooltip([
            {
                mounted: true
            },
            {
                mounted: false
            },
            {
                mounted: true
            }
        ]), "3 removable volumes · 2 mounted\nclick to expand");
    }

    function test_find_volume_matches_exact_device_paths() {
        const volumes = [
            {
                path: "/dev/sdb1"
            },
            {
                path: "/dev/sdc1"
            }
        ];
        compare(Model.findVolume(volumes, "/dev/sdc1").path, "/dev/sdc1");
        compare(Model.findVolume(volumes, "/dev/sdb"), null);
        compare(Model.findVolume([], "/dev/sdb1"), null);
    }
}
