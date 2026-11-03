import QtQuick
import QtTest
import "../../components"

Item {
    id: host
    QtObject {
        id: fixtureConfig
        property color selectionBackground: "#bb8855"
        property color border: "#554433"
    }
    Component {
        id: meterComponent
        VolumeMeter { config: fixtureConfig; width: 126; height: 14; segmentCount: 20 }
    }
    TestCase {
        name: "OsdVolumeMeter"
        function test_segments_and_colors() {
            const meter = createTemporaryObject(meterComponent, host);
            meter.value = 0.8;
            compare(meter.activeSegments, 16);
            compare(findChild(meter, "volumeSegment-15").color, fixtureConfig.selectionBackground);
            compare(findChild(meter, "volumeSegment-16").color, fixtureConfig.border);
            const last = findChild(meter, "volumeSegment-19");
            wait(0);
            verify(last.x + last.width <= meter.width + 0.01);
        }
        function test_ceiling_zero_and_out_of_range_values() {
            const meter = createTemporaryObject(meterComponent, host);
            meter.maximum = 1.1;
            meter.value = 1.1;
            compare(meter.activeSegments, 20);
            meter.value = 3;
            compare(meter.activeSegments, 20);
            meter.value = -1;
            compare(meter.activeSegments, 0);
            meter.value = 0.01;
            compare(meter.activeSegments, 1);
            meter.maximum = 0;
            compare(meter.activeSegments, 0);
        }
        function test_more_segments_keep_wide_popup_track_pipe_shaped() {
            const meter = createTemporaryObject(meterComponent, host);
            meter.width = 400;
            meter.height = 14;
            meter.segmentCount = Math.floor((meter.width + meter.spacing) / (4 + meter.spacing));
            meter.value = 0.8;
            compare(meter.segmentCount, 57);
            compare(meter.activeSegments, 46);
            const segment = findChild(meter, "volumeSegment-0");
            verify(segment.width < 4.1);
            compare(segment.height, 14);
        }
    }
}
