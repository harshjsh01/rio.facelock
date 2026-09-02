import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool faceUnlockConfigured: false
  property string faceState: "idle" // "idle", "scanning", "verifying", "success", "failed"
  property bool weeklyPasswordRequired: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: weeklyPasswordRequired ? "Enter password (weekly check)" : "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.25)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Android-style Face Unlock Indicator
    Item {
      id: faceBadge
      visible: root.faceUnlockConfigured || root.weeklyPasswordRequired
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: inputField.top
      anchors.bottomMargin: 28
      width: 80
      height: 80

      // Glowing / Pulsing circular background
      Rectangle {
        id: badgeBg
        anchors.fill: parent
        radius: width / 2
        color: {
          if (root.weeklyPasswordRequired) return Qt.rgba(1.0, 0.65, 0.0, 0.18)
          if (root.faceState === "success") return Qt.rgba(0.2, 0.85, 0.4, 0.28)
          if (root.faceState === "failed") return Qt.rgba(1.0, 0.3, 0.3, 0.18)
          if (root.faceState === "scanning" || root.faceState === "verifying") return Qt.rgba(0.3, 0.65, 1.0, 0.2)
          return Qt.rgba(1.0, 1.0, 1.0, 0.1)
        }
        border.color: {
          if (root.weeklyPasswordRequired) return Qt.rgba(1.0, 0.65, 0.0, 0.7)
          if (root.faceState === "success") return Qt.rgba(0.2, 0.85, 0.4, 0.85)
          if (root.faceState === "failed") return Qt.rgba(1.0, 0.3, 0.3, 0.7)
          if (root.faceState === "scanning" || root.faceState === "verifying") return Qt.rgba(0.3, 0.65, 1.0, 0.7)
          return Qt.rgba(1.0, 1.0, 1.0, 0.2)
        }
        border.width: 2

        Behavior on color { ColorAnimation { duration: 250 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Pulsing scanning wave
        Rectangle {
          id: pulseRing
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.color: Qt.rgba(0.3, 0.65, 1.0, 0.8)
          border.width: 2
          visible: (root.faceState === "scanning" || root.faceState === "verifying") && !root.weeklyPasswordRequired
          scale: 1.0
          opacity: 1.0

          SequentialAnimation {
            running: pulseRing.visible
            loops: Animation.Infinite
            ParallelAnimation {
              NumberAnimation { target: pulseRing; property: "scale"; from: 1.0; to: 1.45; duration: 1000; easing.type: Easing.OutQuad }
              NumberAnimation { target: pulseRing; property: "opacity"; from: 0.9; to: 0.0; duration: 1000; easing.type: Easing.OutQuad }
            }
            PauseAnimation { duration: 150 }
          }
        }
      }

      // Center Animated Emoji
      Text {
        id: emojiIcon
        anchors.centerIn: parent
        font.pixelSize: 36
        text: {
          if (root.weeklyPasswordRequired) return "🔑"
          if (root.faceState === "success") return "😊"
          if (root.faceState === "scanning" || root.faceState === "verifying") return "👀"
          if (root.faceState === "failed") return "😕"
          return "👤"
        }

        scale: root.faceState === "success" ? 1.3 : (root.faceState === "scanning" ? 1.1 : 1.0)
        Behavior on scale {
          NumberAnimation { duration: 300; easing.type: Easing.OutBack }
        }
      }

      // Status text label underneath
      Text {
        anchors.top: badgeBg.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.body * 0.85)
        color: {
          if (root.weeklyPasswordRequired) return Qt.rgba(1.0, 0.75, 0.2, 0.95)
          if (root.faceState === "success") return Qt.rgba(0.3, 0.9, 0.5, 0.95)
          if (root.faceState === "failed") return Qt.rgba(1.0, 0.4, 0.4, 0.95)
          return Qt.rgba(1.0, 1.0, 1.0, 0.75)
        }
        text: {
          if (root.weeklyPasswordRequired) return "Weekly password check"
          if (root.faceState === "success") return "Face verified!"
          if (root.faceState === "scanning" || root.faceState === "verifying") return "Looking for face…"
          if (root.faceState === "failed") return "Face not recognized"
          return ""
        }
        visible: text.length > 0
      }
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
