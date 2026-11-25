import QtQuick
import QtQuick.Layouts

// Session / power menu for the bar. Emits action(name); Bar.qml runs the
// matching command. Reboot and shutdown arm on the first click and fire on the
// second, so a stray click cannot drop the session.
Item {
  id: root

  property var theme
  property string fontName: "Inter"

  property string armed: ""      // "", "reboot" or "poweroff"

  signal action(string name)

  implicitWidth: 200
  implicitHeight: 174   // 5 rows x 30 + 4 x 2 spacing + 2 x 8 margins

  function reset() { root.armed = ""; }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: root.theme.bgSurface
    border.color: root.theme.bgBorder
    border.width: 1

    ColumnLayout {
      id: column
      anchors.fill: parent
      anchors.margins: 8
      spacing: 2

      Repeater {
        model: [
          { key: "lock",     glyph: "\uF023", label: "Lock",      danger: false },
          { key: "suspend",  glyph: "\uF186", label: "Suspend",   danger: false },
          { key: "logout",   glyph: "\uF08B", label: "Log out",   danger: false },
          { key: "reboot",   glyph: "\uF021", label: "Reboot",    danger: true  },
          { key: "poweroff", glyph: "\uF011", label: "Shut down", danger: true  }
        ]

        Rectangle {
          id: row
          required property var modelData

          readonly property bool isArmed: root.armed === row.modelData.key

          Layout.fillWidth: true
          implicitHeight: 30
          radius: 8
          color: row.isArmed
            ? root.theme.accentRed
            : (rowMa.containsMouse ? root.theme.bgHover : "transparent")

          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            text: row.modelData.glyph
            color: row.isArmed
              ? root.theme.bgBase
              : (row.modelData.danger ? root.theme.accentRed : root.theme.textSecondary)
            font.pixelSize: 14
            font.family: root.fontName
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 34
            text: row.isArmed
              ? (row.modelData.key === "poweroff" ? "Really shut down?" : "Really reboot?")
              : row.modelData.label
            color: row.isArmed ? root.theme.bgBase : root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.fontName
            font.bold: row.isArmed
          }

          MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onExited: { if (row.isArmed) root.armed = ""; }
            onClicked: {
              if (row.modelData.danger) {
                if (!row.isArmed) {
                  root.armed = row.modelData.key;
                  return;
                }
                root.armed = "";
              }
              root.action(row.modelData.key);
            }
          }
        }
      }
    }
  }
}
