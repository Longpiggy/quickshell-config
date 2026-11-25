import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  property var theme
  property string fontName: "Inter"

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  implicitWidth: 280
  implicitHeight: 320

  function shiftMonth(delta) {
    let m = root.viewMonth + delta;
    let y = root.viewYear;
    while (m < 0) {
      m += 12;
      y -= 1;
    }
    while (m > 11) {
      m -= 12;
      y += 1;
    }
    root.viewMonth = m;
    root.viewYear = y;
  }

  function goToday() {
    const now = new Date();
    root.viewYear = now.getFullYear();
    root.viewMonth = now.getMonth();
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: root.theme.bgSurface
    border.color: root.theme.bgBorder
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
          width: 28
          height: 28
          radius: 8
          color: prevMa.containsMouse ? root.theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "‹"
            color: root.theme.textPrimary
            font.pixelSize: 16
            font.family: root.fontName
            font.bold: true
          }

          MouseArea {
            id: prevMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.shiftMonth(-1)
          }
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
          color: root.theme.textPrimary
          font.pixelSize: 13
          font.family: root.fontName
          font.bold: true

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToday()
          }
        }

        Rectangle {
          width: 28
          height: 28
          radius: 8
          color: nextMa.containsMouse ? root.theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "›"
            color: root.theme.textPrimary
            font.pixelSize: 16
            font.family: root.fontName
            font.bold: true
          }

          MouseArea {
            id: nextMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.shiftMonth(1)
          }
        }
      }

      DayOfWeekRow {
        Layout.fillWidth: true
        locale: grid.locale
        delegate: Text {
          required property string shortName
          text: shortName
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.fontName
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          width: 32
        }
      }

      MonthGrid {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        month: root.viewMonth
        year: root.viewYear
        locale: Qt.locale()
        spacing: 2

        delegate: Item {
          id: dayCell
          required property var model
          width: 32
          height: 32

          readonly property bool inMonth: model.month === grid.month
          readonly property bool today: {
            const now = new Date();
            return dayCell.inMonth
                && model.day === now.getDate()
                && grid.month === now.getMonth()
                && grid.year === now.getFullYear();
          }

          Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 8
            color: dayCell.today ? root.theme.accentPrimary : "transparent"

            Text {
              anchors.centerIn: parent
              text: model.day
              color: dayCell.today
                     ? root.theme.bgBase
                     : (dayCell.inMonth ? root.theme.textPrimary : root.theme.textMuted)
              font.pixelSize: 11
              font.family: root.fontName
              font.bold: dayCell.today
              opacity: dayCell.inMonth ? 1 : 0.45
            }
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "Today · " + Qt.formatDate(new Date(), "ddd d MMM")
        color: root.theme.textSecondary
        font.pixelSize: 10
        font.family: root.fontName

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.goToday()
        }
      }
    }
  }
}
