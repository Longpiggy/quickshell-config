import Quickshell
import QtQuick

// Coffee-cup pill for the bar. Clicking it flips the shared caffeine state,
// which CaffeineToggle turns into a Wayland idle-inhibit request.
Rectangle {
  id: root

  property var theme: DefaultTheme {}
  property string font: "Inter"
  property bool hovered: false

  readonly property bool active: Caffeine.active

  width: 24
  height: 24
  radius: 12

  color: root.active ? root.theme.accentOrange
       : root.hovered ? root.theme.bgHover
       : root.theme.bgSurface

  Accessible.role: Accessible.Button
  Accessible.name: root.active
    ? "Caffeine on: sleep and screen locking are inhibited"
    : "Caffeine off: normal sleep and screen locking"
  Accessible.onPressAction: Caffeine.toggle()

  Behavior on color { ColorAnimation { duration: 150 } }

  Text {
    anchors.centerIn: parent
    text: "\u{F0176}"
    color: root.active ? root.theme.bgBase : root.theme.textMuted
    font.pixelSize: 14
    font.family: root.font
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: Caffeine.toggle()
  }
}
