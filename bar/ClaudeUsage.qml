pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Reads ~/.cache/claude-usage.json, written by Claude Code's statusline script.
Singleton {
  id: root

  property real fiveHour: -1   // percent used, -1 = unknown
  property real sevenDay: -1
  property real fiveReset: 0   // epoch seconds, 0 = unknown
  property real sevenReset: 0
  property real updated: 0     // epoch seconds

  readonly property bool stale: updated === 0 || (Date.now() / 1000 - updated) > 6 * 3600

  function toEpoch(v) {
    if (!v) return 0;
    if (typeof v === "string") return Date.parse(v) / 1000 || 0;
    return v > 1e12 ? v / 1000 : v;
  }

  FileView {
    path: Quickshell.env("HOME") + "/.cache/claude-usage.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const d = JSON.parse(text());
        root.fiveHour = d.five_hour ? d.five_hour.used_percentage : -1;
        root.sevenDay = d.seven_day ? d.seven_day.used_percentage : -1;
        root.fiveReset = root.toEpoch(d.five_hour ? d.five_hour.resets_at : 0);
        root.sevenReset = root.toEpoch(d.seven_day ? d.seven_day.resets_at : 0);
        root.updated = d.ts || 0;
      } catch (e) {}
    }
  }
}
