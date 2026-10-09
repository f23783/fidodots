import Quickshell
import QtQuick
import "panel"
import "codexbar"
import "wifi"
import "bluetooth"

ShellRoot {
    Panel {}
    PowerMenu {}
    CodexPopup {}
    WifiPanel {}
    BluetoothPanel {}
}
