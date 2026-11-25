  import Quickshell
  import QtQuick
  import QtQuick.Layouts
  import Quickshell.Hyprland
  import Quickshell.Wayland
  import Quickshell.Widgets
  import Quickshell.Services.SystemTray
  import Quickshell.Io
  import Quickshell.Services.Mpris
  import Quickshell.Services.Pipewire
  import "../idle-inhibitor"
  Scope {
    id: root
    property var theme: DefaultTheme {}
    property string font: "Inter"
    property bool barVisible: true

    // MPRIS active player
    property var activePlayer: {
      const players = Mpris.players.values;
      if (!players || players.length === 0) return null;
      for (const p of players) {
        if (p.playbackState === MprisPlaybackState.Playing) return p;
      }
      // Nothing playing: prefer a real music player over a paused browser tab,
      // so the pill doesn't show a web page title.
      const isBrowser = p => /firefox|chrom|brave|vivaldi|zen|librewolf/i.test(p.dbusName || "");
      for (const p of players) {
        if (!isBrowser(p)) return p;
      }
      return players[0];
    }

    IpcHandler {
      target: "bar"
      function toggle(): void { root.barVisible = !root.barVisible; }
    }

    PwObjectTracker {
      objects: [Pipewire.defaultAudioSink]
    }

    // Brightness state
    property real brightnessValue: 0
    property real brightnessMax: 1

    FileView {
      id: brightnessFile
      path: ""
      watchChanges: true
      onFileChanged: brightnessReadProc.running = true
    }

    Process {
      id: brightnessReadProc
      command: ["brightnessctl", "get"]
      running: false
      stdout: StdioCollector {
        onStreamFinished: {
          const val = parseInt(text.trim());
          if (!isNaN(val) && root.brightnessMax > 0)
            root.brightnessValue = val / root.brightnessMax;
        }
      }
    }

    Process {
      id: brightnessSetProc
      running: false
    }

    Process {
      id: powerProc
      running: false
    }
    Process {
      id: backlightDiscovery
      command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
      running: true
      stdout: StdioCollector {
        onStreamFinished: {
          const lines = text.trim().split("\n");
          if (lines.length >= 2) {
            const max = parseInt(lines[1]);
            if (!isNaN(max) && max > 0) root.brightnessMax = max;
            brightnessFile.path = lines[0];
            brightnessReadProc.running = true;
          }
        }
      }
    }

    Variants {
      model: Quickshell.screens

      Scope {
        id: screenRoot
        required property var modelData
        property bool calendarOpen: false
        property bool powerMenuOpen: false

      PanelWindow {
        id: barWindow
        screen: screenRoot.modelData
        visible: root.barVisible

        anchors {
          top: true
          left: true
          right: true
        }

        implicitHeight: 32
        color: root.theme.bgBase

        Item {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10

          // Left section: Now Playing
          Row {
            id: leftSection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Workspaces
          Row {
            id: workspaceSection
            // Workspaces remain in the left section
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

              Repeater {
                model: Hyprland.workspaces

                Rectangle {
                  id: wsPill
                  required property var modelData
                  property bool urgentBlink: false

                  Accessible.role: Accessible.Button
                  Accessible.name: "Workspace " + modelData.id + (modelData.focused ? ", active" : "") + (modelData.urgent ? ", urgent" : "")

                  width: modelData.focused ? 32 : 24
                  height: 24
                  radius: 12
                  color: modelData.focused ? root.theme.accentPrimary :
                        modelData.urgent && urgentBlink ? root.theme.accentRed : root.theme.bgSurface

                  Behavior on color {
                    ColorAnimation { duration: 150 }
                  }

                  SequentialAnimation {
                    loops: Animation.Infinite
                    running: wsPill.modelData.urgent && !wsPill.modelData.focused

                    PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
                    PauseAnimation { duration: 500 }
                    PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
                    PauseAnimation { duration: 500 }

                    onStopped: wsPill.urgentBlink = false
                  }

                  Text {
                    anchors.centerIn: parent
                    text: wsPill.modelData.id
                    color: wsPill.modelData.focused ? root.theme.bgBase : root.theme.textPrimary
                    font.pixelSize: 11
                    font.family: root.font
                    font.bold: wsPill.modelData.focused
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: wsPill.modelData.activate()
                  }

                  Behavior on width {
                    NumberAnimation { duration: 150 }
                  }
                }
              }
            }



            // Now Playing
            Rectangle {
              height: 24
              width: nowPlayingContent.width + 16
              radius: 12
              color: root.theme.bgSurface
              visible: root.activePlayer !== null

              Accessible.role: Accessible.Button
              Accessible.name: {
                if (!root.activePlayer) return "No media";
                const artist = root.activePlayer.trackArtist || "";
                const title = root.activePlayer.trackTitle || "";
                return "Now playing: " + (artist ? artist + " - " : "") + title;
              }

              Row {
                id: nowPlayingContent
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                spacing: 6

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.activePlayer && root.activePlayer.isPlaying ? "󰐊" : "󰏤"
                  color: root.theme.accentPrimary
                  font.pixelSize: 14
                  font.family: root.font
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    if (!root.activePlayer) return "";
                    const artist = root.activePlayer.trackArtist || "";
                    const title = root.activePlayer.trackTitle || "";
                    return artist ? artist + " - " + title : title;
                  }
                  color: root.theme.textPrimary
                  font.pixelSize: 11
                  font.family: root.font
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, 200)
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activePlayer.togglePlaying()
              }
            }

          }

          // Center section: Time / Date
          Row {
            id: centerGroup
            anchors.centerIn: parent
            spacing: 6

          Rectangle {
            id: timePill
            height: 24
            width: timeDate.width + 16
            radius: 12
            color: root.theme.bgSurface

            Accessible.role: Accessible.Button
            Accessible.name: "Calendar: " + Time.timeString + " " + Time.dateString

            Row {
              id: timeDate
              anchors.centerIn: parent
              spacing: 8

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Time.timeString
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.family: root.font
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Time.dateString
                color: root.theme.textSecondary
                font.pixelSize: 12
                font.family: root.font
              }
            }

            Process {
              id: betterbirdCalProc
              command: ["betterbird", "-calendar"]
              running: false
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                  screenRoot.calendarOpen = false;
                  betterbirdCalProc.running = true;
                  return;
                }
                if (screenRoot.calendarOpen) {
                  screenRoot.calendarOpen = false;
                } else {
                  calendarPopup.goToday();
                  screenRoot.calendarOpen = true;
                }
              }
            }
          }

          // Caffeine: prohibit idle sleep / screen locking
          CaffeinePill {
            id: caffeinePill
            theme: root.theme
            font: root.font
          }
          }

          // Right section: System Info + System Tray
          Row {
            id: rightSection
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

          // Volume

            // Claude usage (5h / 7d)
            ClaudePill {
              theme: root.theme
              font: root.font
              anchors.verticalCenter: parent.verticalCenter
            }

                        // Temperature
              Rectangle {
                height: 24
                width: tempContent.width + 12
                radius: 12
                color: root.theme.bgSurface
                Accessible.role: Accessible.StaticText
                Accessible.name: "Temperature: " + SystemInfo.temperature

                Row {
                  id: tempContent
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰔏"
                    color: root.theme.accentRed
                    font.pixelSize: 14
                    font.family: root.font
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemInfo.temperature
                    color: root.theme.textPrimary
                    font.pixelSize: 11
                    font.family: root.font
                  }
                }
              }

            // Brightness
            Rectangle {
              height: 24
              width: brightContent.width + 12
              radius: 12
              color: root.theme.bgSurface
              visible: brightnessFile.path !== ""

              Accessible.role: Accessible.StaticText
              Accessible.name: "Brightness: " + Math.round(root.brightnessValue * 100) + "%"

              Row {
                id: brightContent
                anchors.centerIn: parent
                spacing: 6

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰃠"
                  color: root.theme.accentOrange
                  font.pixelSize: 14
                  font.family: root.font
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Math.round(root.brightnessValue * 100) + "%"
                  color: root.theme.textPrimary
                  font.pixelSize: 11
                  font.family: root.font
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onWheel: (wheel) => {
                  brightnessSetProc.command = wheel.angleDelta.y > 0
                    ? ["brightnessctl", "set", "5%+"]
                    : ["brightnessctl", "set", "5%-"];
                  brightnessSetProc.running = true;
                }
              }
            }

            // System Info
            Row {
              id: sysInfo

              readonly property color batteryColor: {
                if (SystemInfo.batteryCharging) return root.theme.accentGreen;
                if (SystemInfo.batteryLevelRaw > 20) return root.theme.batteryGood;
                if (SystemInfo.batteryLevelRaw > 10) return root.theme.batteryWarning;
                return root.theme.batteryCritical;
              }

              spacing: 4

              // CPU
              Rectangle {
                height: 24
                width: cpuContent.width + 12
                radius: 12
                color: root.theme.bgSurface
                Accessible.role: Accessible.StaticText
                Accessible.name: "CPU: " + SystemInfo.cpuUsage

                Row {
                  id: cpuContent
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰻠"
                    color: root.theme.accentOrange
                    font.pixelSize: 14
                    font.family: root.font
                  }
                  Text {
                    // Fixed width (sized for the widest value) so the pill
                    // doesn't resize and shove its neighbours around.
                    width: cpuWidest.advanceWidth
                    horizontalAlignment: Text.AlignLeft
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemInfo.cpuUsage
                    color: root.theme.textPrimary
                    font.pixelSize: 11
                    font.family: root.font

                    TextMetrics {
                      id: cpuWidest
                      text: "100.0%"
                      font.pixelSize: 11
                      font.family: root.font
                    }
                  }
                }
              }

              // RAM
              Rectangle {
                height: 24
                width: ramContent.width + 12
                radius: 12
                color: root.theme.bgSurface
                Accessible.role: Accessible.StaticText
                Accessible.name: "RAM: " + SystemInfo.memoryUsage

                Row {
                  id: ramContent
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍛"
                    color: root.theme.accentCyan
                    font.pixelSize: 14
                    font.family: root.font
                  }
                  Text {
                    // Fixed width (sized for the widest plausible reading, using
                    // the real total) so the pill doesn't resize and shove its
                    // neighbours around.
                    width: ramWidest.advanceWidth
                    horizontalAlignment: Text.AlignLeft
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemInfo.memoryUsage
                    color: root.theme.textPrimary
                    font.pixelSize: 11
                    font.family: root.font

                    TextMetrics {
                      id: ramWidest
                      text: "100% 99.9G/" + (SystemInfo.memoryUsage.split("/")[1] || "99G")
                      font.pixelSize: 11
                      font.family: root.font
                    }
                  }
                }
              }

              // Network
              Rectangle {
                height: 24
                width: netContent.width + 12
                radius: 12
                color: root.theme.bgSurface
                Accessible.role: Accessible.StaticText
                Accessible.name: {
                  if (SystemInfo.networkType === "ethernet") return "Network: Ethernet"
                  if (SystemInfo.networkType === "wifi") return "Network: WiFi " + SystemInfo.networkInfo
                  return "Network: Disconnected"
                }

                Row {
                  id: netContent
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                      if (SystemInfo.networkType === "ethernet") return "󰈀"
                      if (SystemInfo.networkType === "wifi") return "󰖩"
                      return "󰖪"
                    }
                    color: SystemInfo.networkType === "disconnected" ? root.theme.textMuted : root.theme.accentGreen
                    font.pixelSize: 14
                    font.family: root.font
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemInfo.networkInfo
                    color: root.theme.textPrimary
                    font.pixelSize: 11
                    font.family: root.font
                  }
                }
              }
            }

                      Rectangle {
              height: 24
              width: volContent.width + 12
              radius: 12
              color: root.theme.bgSurface

              Accessible.role: Accessible.StaticText
              Accessible.name: {
                const sink = Pipewire.defaultAudioSink;
                if (!sink || !sink.audio) return "Volume";
                if (sink.audio.muted) return "Volume: muted";
                return "Volume: " + Math.round(sink.audio.volume * 100) + "%";
              }

              Row {
                id: volContent
                anchors.centerIn: parent
                spacing: 6

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    const sink = Pipewire.defaultAudioSink;
                    if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
                    if (sink.audio.volume < 0.33) return "󰕿";
                    if (sink.audio.volume < 0.66) return "󰖀";
                    return "󰕾";
                  }
                  color: {
                    const sink = Pipewire.defaultAudioSink;
                    if (!sink || !sink.audio || sink.audio.muted) return root.theme.textMuted;
                    return root.theme.accentPrimary;
                  }
                  font.pixelSize: 14
                  font.family: root.font
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    const sink = Pipewire.defaultAudioSink;
                    if (!sink || !sink.audio) return "–";
                    if (sink.audio.muted) return "Mute";
                    return Math.round(sink.audio.volume * 100) + "%";
                  }
                  color: root.theme.textPrimary
                  font.pixelSize: 11
                  font.family: root.font
                }
              }

              Process {
                id: pavucontrolProc
                command: ["pavucontrol"]
                running: false
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                  if (mouse.button === Qt.RightButton) {
                    pavucontrolProc.running = true;
                    return;
                  }
                  const sink = Pipewire.defaultAudioSink;
                  if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
                }
                onWheel: (wheel) => {
                  const sink = Pipewire.defaultAudioSink;
                  if (!sink || !sink.audio) return;
                  const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                  sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
                }
              }
            }

            // System Tray
            // There's an issue that some tray not display correctly.
            // https://github.com/quickshell-mirror/quickshell/issues/26
            // https://github.com/quickshell-mirror/quickshell/pull/777
            Rectangle {
              implicitHeight: 24
              implicitWidth: trayIcons.implicitWidth + 4
              radius: 12
              color: root.theme.bgSurface

              RowLayout {
                id: trayIcons
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                  model: SystemTray.items

                  MouseArea {
                    id: trayDelegate
                    required property SystemTrayItem modelData

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.tooltipTitle || modelData.title || "System tray item"

                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: (mouse) => {
                      if (mouse.button === Qt.LeftButton) {
                        modelData.activate()
                      } else if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                          menuAnchor.open()
                        }
                      } else if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate()
                      }
                    }

                    IconImage {
                      anchors.centerIn: parent
                      source: trayDelegate.modelData.icon
                      implicitSize: 16
                    }

                    QsMenuAnchor {
                      id: menuAnchor
                      menu: trayDelegate.modelData.menu

                      anchor.window: trayDelegate.QsWindow.window
                      anchor.adjustment: PopupAdjustment.Flip
                      anchor.onAnchoring: {
                        const window = trayDelegate.QsWindow.window;
                        const widgetRect = window.contentItem.mapFromItem(
                          trayDelegate, 0, trayDelegate.height,
                          trayDelegate.width, trayDelegate.height);
                        menuAnchor.anchor.rect = widgetRect;
                      }
                    }
                  }
                }
              }
            }
          }
          // Power / session button, far right
          Row {
            id: powerSection
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              id: powerButton
              width: 24
              height: 24
              radius: 12
              color: (powerMa.containsMouse || screenRoot.powerMenuOpen)
                ? root.theme.bgHover
                : root.theme.bgSurface

              Accessible.role: Accessible.Button
              Accessible.name: "Power menu"

              Behavior on color { ColorAnimation { duration: 150 } }

              Text {
                anchors.centerIn: parent
                text: "\uF011"
                color: screenRoot.powerMenuOpen ? root.theme.accentPrimary : root.theme.textMuted
                font.pixelSize: 14
                font.family: root.font
              }

              MouseArea {
                id: powerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  powerMenu.reset();
                  screenRoot.powerMenuOpen = !screenRoot.powerMenuOpen;
                }
              }
            }
          }
        }

      }

      PanelWindow {
        id: calendarOverlay
        screen: screenRoot.modelData
        visible: screenRoot.calendarOpen
        focusable: true
        color: "transparent"
        implicitWidth: screenRoot.modelData.width
        implicitHeight: screenRoot.modelData.height
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "quickshell-calendar"

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        MouseArea {
          anchors.fill: parent
          onClicked: screenRoot.calendarOpen = false
        }

        MouseArea {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 40
          width: calendarPopup.width
          height: calendarPopup.height
          // Absorb clicks so the dimmed backdrop does not close the popup

          CalendarPopup {
            id: calendarPopup
            anchors.fill: parent
            theme: root.theme
            fontName: root.font
          }
        }
      }
      // Power / session menu overlay
      PanelWindow {
        id: powerOverlay
        screen: screenRoot.modelData
        visible: screenRoot.powerMenuOpen
        focusable: true
        color: "transparent"
        implicitWidth: screenRoot.modelData.width
        implicitHeight: screenRoot.modelData.height
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "quickshell-power"

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        MouseArea {
          anchors.fill: parent
          onClicked: screenRoot.powerMenuOpen = false
        }

        MouseArea {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: 40
          anchors.rightMargin: 12
          width: powerMenu.width
          height: powerMenu.height

          PowerMenu {
            id: powerMenu
            anchors.fill: parent
            theme: root.theme
            fontName: root.font
            onAction: (name) => {
              screenRoot.powerMenuOpen = false;
              if (name === "lock") powerProc.command = ["hyprlock"];
              else if (name === "suspend") powerProc.command = ["systemctl", "suspend"];
              else if (name === "reboot") powerProc.command = ["systemctl", "reboot"];
              else if (name === "poweroff") powerProc.command = ["systemctl", "poweroff"];
              else if (name === "logout") powerProc.command = ["hyprctl", "dispatch", "exit"];
              powerProc.running = true;
            }
          }
        }
      }
      } // screenRoot
    }
  }
