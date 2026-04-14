pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: row

    required property string title
    required property var iconSource
    required property bool active
    property string secondaryText: ""
    property bool pinned: false
    property bool dragging: false

    signal clicked(var sourceItem)
    signal rightClicked(var sourceItem)

    implicitHeight: Kirigami.Units.gridUnit * 2

    opacity: row.dragging ? 0.5 : 1.0

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: rowMouseArea.containsMouse || row.active
            ? Kirigami.Theme.highlightColor
            : "transparent"
        opacity: row.active ? 0.22 : 0.14
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        // Leave right margin for the drag handle sitting outside this layout
        anchors.rightMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 3
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: row.iconSource
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: row.title
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        PlasmaComponents3.Label {
            visible: row.secondaryText.length > 0
            text: row.secondaryText
            opacity: 0.8
        }

        Kirigami.Icon {
            source: "window-pin"
            visible: row.pinned
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            opacity: 0.6
        }
    }

    // Drag handle indicator (right side) — the actual MouseArea is in main.qml
    Kirigami.Icon {
        id: dragHandleIcon
        source: "handle-sort"
        anchors.right: parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: Kirigami.Units.iconSizes.small
        opacity: rowMouseArea.containsMouse || row.dragging ? 0.6 : 0.0
    }

    MouseArea {
        id: rowMouseArea
        anchors.fill: parent
        // Leave room for the drag handle on the right
        anchors.rightMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                row.rightClicked(row);
                return;
            }
            row.clicked(row);
        }
    }
}
