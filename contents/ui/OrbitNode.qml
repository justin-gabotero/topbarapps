import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: node

    property int taskRow
    property string taskTitle
    property string taskApp
    property var taskIcon
    property bool minimized: false
    property int windowCount: 1
    readonly property string appDisplayText: {
        const extraCount = Math.max(0, windowCount - 1);
        if (extraCount === 0)
            return node.taskApp;
        return node.taskApp + "  [+" + extraCount + " windows]";
    }

    readonly property color accentColor: iconColors.dominant.hslSaturation > 0.1
        ? iconColors.dominant
        : Kirigami.Theme.highlightColor

    Kirigami.ImageColors {
        id: iconColors
        source: node.taskIcon || "application-x-executable"
    }
    property int nodeWidth: 160
    property real openScale: 1.0
    readonly property bool hovered: nodeHoverHandler.hovered
    property real hoverScale: hovered ? 1.02 : 1.0

    signal activate()
    signal close()
    signal openContextMenu(var sourceItem)

    width: nodeWidth
    implicitHeight: Kirigami.Units.gridUnit * 1.3
    implicitWidth: nodeWidth
    radius: 5

    color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, hovered ? 0.40 : 0.30)
    border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, hovered ? 0.55 : 0.45)
    border.width: 1
    opacity: node.minimized ? 0.6 : 1.0
    scale: openScale * hoverScale

    Behavior on color {
        ColorAnimation { duration: 140 }
    }
    Behavior on scale {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    HoverHandler {
        id: nodeHoverHandler
    }

    Accessible.role: Accessible.Button
    Accessible.name: node.appDisplayText + (node.taskTitle ? " · " + node.taskTitle : "")

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: node.taskIcon || "application-x-executable"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        QQC2.Label {
            text: node.appDisplayText
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        QQC2.ToolButton {
            icon.name: "window-close-symbolic"
            implicitWidth: Kirigami.Units.gridUnit
            implicitHeight: Kirigami.Units.gridUnit
            flat: true
            opacity: hovered ? 0.95 : 0.72

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            onClicked: node.close()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) node.activate();
            else if (mouse.button === Qt.MiddleButton) node.close();
            else if (mouse.button === Qt.RightButton) node.openContextMenu(node);
        }
    }
}
