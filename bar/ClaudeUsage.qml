pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Claude plan usage from two sources; whichever reported most recently wins.
//  1. ~/.config/Claude/plan-usage-history.json: sampled by the Claude desktop
//     app about every 15 minutes. No reset times.
//  2. ~/.cache/claude-usage.json: written by Claude Code's statusline script
//     (interactive terminal sessions only). Includes reset times.
Singleton {
  id: root

  property real now: Date.now() / 1000

  // Desktop app source
  property real appFive: -1
  property real appSeven: -1
  property real appTs: 0

  // Statusline source
  property real cacheFive: -1
  property real cacheSeven: -1
  property real cacheFiveReset: 0   // epoch seconds, 0 = unknown
  property real cacheSevenReset: 0
  property real cacheTs: 0

  readonly property bool useApp: appTs > cacheTs
  readonly property real updated: Math.max(appTs, cacheTs)  // epoch seconds

  readonly property real fiveRaw: useApp ? appFive : cacheFive
  readonly property real sevenRaw: useApp ? appSeven : cacheSeven

  // Reset times only come from the statusline. Keep one while it is still in
  // the future, even when the desktop numbers are newer.
  readonly property real fiveReset: cacheFiveReset > now ? cacheFiveReset : (useApp ? 0 : cacheFiveReset)
  readonly property real sevenReset: cacheSevenReset > now ? cacheSevenReset : (useApp ? 0 : cacheSevenReset)

  // A window whose reset time has passed has started over, so the last
  // statusline number no longer applies: show 0 until fresh data arrives.
  readonly property bool fiveExpired: !useApp && fiveReset > 0 && fiveReset <= now
  readonly property bool sevenExpired: !useApp && sevenReset > 0 && sevenReset <= now
  readonly property real fiveHour: fiveRaw < 0 ? -1 : (fiveExpired ? 0 : fiveRaw)
  readonly property real sevenDay: sevenRaw < 0 ? -1 : (sevenExpired ? 0 : sevenRaw)

  // The desktop app samples every ~15 minutes, so an hour of silence is stale.
  readonly property bool stale: updated === 0 || (now - updated) > 3600

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: {
      root.now = Date.now() / 1000;
      appFile.reload();   // insurance against a missed change event
    }
  }

  function toEpoch(v) {
    if (!v) return 0;
    if (typeof v === "string") return Date.parse(v) / 1000 || 0;
    return v > 1e12 ? v / 1000 : v;
  }

  FileView {
    id: appFile
    path: Quickshell.env("HOME") + "/.config/Claude/plan-usage-history.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const samples = JSON.parse(text()).samples || [];
        for (let i = samples.length - 1; i >= 0; i--) {
          const u = samples[i].u;
          if (u && u.fh !== undefined && u.sd !== undefined) {
            root.appFive = u.fh;
            root.appSeven = u.sd;
            root.appTs = samples[i].t / 1000;
            break;
          }
        }
        root.now = Date.now() / 1000;
      } catch (e) {}
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.cache/claude-usage.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const d = JSON.parse(text());
        root.cacheFive = d.five_hour ? d.five_hour.used_percentage : -1;
        root.cacheSeven = d.seven_day ? d.seven_day.used_percentage : -1;
        root.cacheFiveReset = root.toEpoch(d.five_hour ? d.five_hour.resets_at : 0);
        root.cacheSevenReset = root.toEpoch(d.seven_day ? d.seven_day.resets_at : 0);
        root.cacheTs = d.ts || 0;
        root.now = Date.now() / 1000;
      } catch (e) {}
    }
  }
}
