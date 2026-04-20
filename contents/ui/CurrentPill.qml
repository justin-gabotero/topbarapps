import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Rectangle {
    id: pill

    property TaskManager.TasksModel tasksModel
    property int activeIndex: -1
    property int otherCount: 0

    signal hoverEnter()
    signal hoverLeave()
    signal closeActive()

    readonly property string appName: activeIndex >= 0
        ? String(tasksModel.data(tasksModel.index(activeIndex, 0), TaskManager.AbstractTasksModel.AppName) || "")
        : "Task Orbit"

    readonly property string windowTitle: activeIndex >= 0
        ? String(tasksModel.data(tasksModel.index(activeIndex, 0), Qt.DisplayRole) || "")
        : ""

    readonly property var taskIcon: activeIndex >= 0
        ? tasksModel.data(tasksModel.index(activeIndex, 0), Qt.DecorationRole)
        : null

    // Strip trailing " — App Name" style suffixes from window titles
    readonly property string shortTitle: windowTitle.replace(/\s[—–-]\s.*$/, "")

    color: Qt.rgba(
        Kirigami.Theme.highlightColor.r,
        Kirigami.Theme.highlightColor.g,
        Kirigami.Theme.highlightColor.b,
        0.16
    )
    border.color: Qt.rgba(
        Kirigami.Theme.highlightColor.r,
        Kirigami.Theme.highlightColor.g,
        Kirigami.Theme.highlightColor.b,
        0.30
    )
    border.width: 1
    radius: height / 2

    implicitHeight: Kirigami.Units.gridUnit * 1.4
    implicitWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2

    Accessible.role: Accessible.Button
    Accessible.name: appName + (shortTitle ? " · " + shortTitle : "")

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: pill.taskIcon || "application-x-executable"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        QQC2.Label {
            text: pill.appName
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 10
        }

        QQC2.Label {
            text: "·"
            opacity: 0.4
            visible: pill.shortTitle.length > 0
        }

        QQC2.Label {
            text: pill.shortTitle
            opacity: 0.7
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            visible: pill.shortTitle.length > 0
        }

        // "+N" badge when other windows exist
        Rectangle {
            visible: pill.otherCount > 0
            radius: Kirigami.Units.smallSpacing
            color: Qt.rgba(1, 1, 1, 0.10)
            implicitHeight: badge.implicitHeight + 2
            implicitWidth: badge.implicitWidth + Kirigami.Units.smallSpacing * 2

            QQC2.Label {
                id: badge
                anchors.centerIn: parent
                text: "+" + pill.otherCount
                font.family: "JetBrains Mono, monospace"
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.6)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onEntered: pill.hoverEnter()
        onExited: pill.hoverLeave()

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                pill.closeActive();
        }
    }
}
