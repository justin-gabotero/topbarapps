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

    signal clicked(var sourceItem)
    signal rightClicked(var sourceItem)

    implicitHeight: Kirigami.Units.gridUnit * 2

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
        anchors.rightMargin: Kirigami.Units.smallSpacing
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
    }

    MouseArea {
        id: rowMouseArea
        anchors.fill: parent
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
