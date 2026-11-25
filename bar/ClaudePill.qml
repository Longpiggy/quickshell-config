import QtQuick
import Quickshell.Io

// Two thin bars (5-hour on top, 7-day below) with percentages.
// Left-click swaps the percentages for time until each window resets.
Rectangle {
  id: root

  property var theme: DefaultTheme {}
  property string font: "Inter"

  readonly property var values: [ClaudeUsage.fiveHour, ClaudeUsage.sevenDay]
  readonly property var resets: [ClaudeUsage.fiveReset, ClaudeUsage.sevenReset]
  property real now: Date.now() / 1000
  property bool showReset: false

  function barColor(p) {
    return p < 50 ? root.theme.accentGreen : p < 80 ? root.theme.accentOrange : root.theme.accentRed;
  }
  function pct(p) { return p < 0 ? "–" : Math.round(p) + "%"; }
  function until(t) {
    if (!t) return "–";
    const s = Math.max(0, t - root.now);
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
    return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m";
  }

  width: 124
  height: 24
  radius: 12
  color: ma.containsMouse ? root.theme.bgHover : root.theme.bgSurface
  opacity: ClaudeUsage.stale ? 0.5 : 1

  Accessible.role: Accessible.ProgressBar
  Accessible.name: "Claude usage: 5 hour " + pct(values[0]) + ", 7 day " + pct(values[1])

  Timer {
    interval: 30000
    running: root.showReset
    repeat: true
    onTriggered: root.now = Date.now() / 1000
  }

  Process {
    id: openProc
    command: ["xdg-open", "https://claude.ai/settings/usage"]
    running: false
  }

  Text {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: 9
    anchors.verticalCenter: parent.verticalCenter
    text: "✳"
    color: root.theme.accentOrange
    font.pixelSize: 12
    font.family: root.font
  }

  Column {
    anchors.left: icon.right
    anchors.leftMargin: 6
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: 2
      Row {
        required property int index
        width: parent.width
        spacing: 5

        Rectangle {
          width: parent.width - label.width - 5
          height: 4
          radius: 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.theme.bgBorder
          Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.values[index])) / 100
            height: parent.height
            radius: 2
            color: root.barColor(root.values[index])
            Behavior on width { NumberAnimation { duration: 200 } }
          }
        }
        Text {
          id: label
          width: 34
          horizontalAlignment: Text.AlignRight
          anchors.verticalCenter: parent.verticalCenter
          text: root.showReset ? root.until(root.resets[index]) : root.pct(root.values[index])
          color: root.showReset ? root.theme.textSecondary : root.barColor(root.values[index])
          font.pixelSize: 9
          font.family: root.font
        }
      }
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        openProc.running = true;
      } else {
        root.now = Date.now() / 1000;
        root.showReset = !root.showReset;
      }
    }
  }
}
