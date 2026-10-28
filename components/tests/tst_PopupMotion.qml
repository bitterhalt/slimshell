import ".."
import QtQuick
import QtTest

TestCase {
    function test_closeKeepsSurfaceMapped() {
        motion.shown = true;
        tryCompare(motion, "progress", 1);
        verify(motion.surfaceVisible);
        visibilitySpy.clear();
        motion.shown = false;
        verify(motion.surfaceVisible);
        compare(visibilitySpy.count, 0);
        tryCompare(motion, "surfaceVisible", false);
        compare(visibilitySpy.count, 1);
    }

    function test_reopenCancelsUnmapping() {
        motion.shown = true;
        tryCompare(motion, "progress", 1);
        visibilitySpy.clear();
        motion.shown = false;
        motion.shown = true;
        wait(100);
        verify(motion.surfaceVisible);
        compare(visibilitySpy.count, 0);
        motion.shown = false;
        tryCompare(motion, "surfaceVisible", false);
    }

    function test_disableDuringClose() {
        motion.animationsEnabled = true;
        motion.shown = true;
        tryCompare(motion, "progress", 1);
        motion.shown = false;
        motion.animationsEnabled = false;
        compare(motion.surfaceVisible, false);
        compare(motion.closing, false);
        compare(motion.progress, 0);
        motion.animationsEnabled = true;
    }

    function test_disableDuringOpen() {
        motion.shown = true;
        motion.animationsEnabled = false;
        compare(motion.surfaceVisible, true);
        compare(motion.progress, 1);
        motion.shown = false;
        compare(motion.surfaceVisible, false);
        motion.animationsEnabled = true;
    }

    function test_switchStyleAndRestart() {
        motion.animationType = "fade";
        motion.shown = true;
        tryCompare(motion, "progress", 1);
        visibilitySpy.clear();
        motion.animationType = "slide";
        motion.restartEnter();
        compare(motion.contentOpacity, 1);
        verify(motion.contentOffset < 0);
        tryCompare(motion, "contentOffset", 0);
        compare(visibilitySpy.count, 0);
        motion.animationType = "fade";
        motion.restartEnter();
        compare(motion.contentOffset, 0);
        verify(motion.contentOpacity < 1);
        tryCompare(motion, "contentOpacity", 1);
        motion.shown = false;
        tryCompare(motion, "surfaceVisible", false);
    }

    function test_initiallyOpened() {
        const popup = createTemporaryObject(initiallyOpen, this);
        verify(popup !== null);
        verify(popup.surfaceVisible);
        tryCompare(popup, "progress", 1);
        popup.shown = false;
        tryCompare(popup, "surfaceVisible", false);
    }

    name: "PopupMotionLifecycle"
    when: windowShown

    PopupMotion {
        id: motion

        openDuration: 30
        slideDistance: 8
        closeDuration: 30
    }

    SignalSpy {
        id: visibilitySpy

        target: motion
        signalName: "surfaceVisibleChanged"
    }

    Component {
        id: initiallyOpen

        PopupMotion {
            shown: true
            openDuration: 30
            slideDistance: 8
            closeDuration: 30
        }

    }

}
