import QtQuick
import QtTest
import "../Scorer.js" as Scorer
import "../Dmenu.js" as Dmenu

TestCase {
    name: "DmenuScoring"

    function test_row_counts() {
        compare(Dmenu.visibleRows(7, false, 2, 20), 7);
        compare(Dmenu.visibleRows(7, true, 2, 20), 2);
        compare(Dmenu.visibleRows(3, true, 10, 20), 3);
        compare(Dmenu.visibleRows(7, true, 0, 20), 0);
        compare(Dmenu.visibleRows(0, false, 10, 20), 0);
        compare(Dmenu.visibleRows(100, false, 200, 15), 15);
        compare(Dmenu.visibleRows(100, true, 200, 15), 15);
    }

    function test_match_ranking() {
        compare(Scorer.scoreLine("fire", "fire"), 10000);
        compare(Scorer.scoreLine("Firefox", "fire"), 5000);
        compare(Scorer.scoreLine("Open Firefox", "fire"), 3000);
        compare(Scorer.scoreLine("wildfire", "fire"), 500);
        compare(Scorer.scoreLine("Firefox browser", "browser fire"), 300);
        compare(Scorer.scoreLine("cat", "fire"), 0);
    }

    function test_literal_paths_and_no_fuzzy_matching() {
        verify(Scorer.scoreLine("/home/user/notes.txt", "/home/user") > 0);
        verify(Scorer.scoreLine("<b>literal</b>", "<b>") > 0);
        compare(Scorer.scoreLine("Firefox", "fier"), 0);
        compare(Scorer.scoreLine("Firefox browser", "browser missing"), 0);
    }

    function test_stable_ties() {
        const lines = ["beta fire", "alpha fire", "fire", "Firefox"];
        const matches = lines.map((text, index) => ({
            text: text, index: index, score: Scorer.scoreLine(text, "fire")
        })).filter(item => item.score > 0)
            .sort((a, b) => b.score - a.score || a.index - b.index);
        compare(matches.map(item => item.text), ["fire", "Firefox", "beta fire", "alpha fire"]);
    }
}
