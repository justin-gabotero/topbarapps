import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Rectangle {
    id: pill

    // --- Properties ---
    property TaskManager.TasksModel tasksModel
    property int activeIndex: -1
    property int otherCount: 0
    
    // Internal flag to prevent focus-grabbing updates during hover
    property bool ignoreUpdates: false

    signal hoverEnter()
    signal hoverLeave()
    signal closeActive()

    // --- Logic: Dynamic Data Extraction ---
    readonly property string appName: {
        const name = activeIndex >= 0 
            ? String(tasksModel.data(tasksModel.index(activeIndex, 0), TaskManager.AbstractTasksModel.AppName) || "")
            : "";
        return name.length > 0 ? name : "Task Orbit";
    }

    readonly property string windowTitle: activeIndex >= 0
        ? String(tasksModel.data(tasksModel.index(activeIndex, 0), Qt.DisplayRole) || "")
        : ""

    readonly property var taskIcon: activeIndex >= 0
        ? tasksModel.data(tasksModel.index(activeIndex, 0), Qt.DecorationRole)
        : "plasma" 

    readonly property string shortTitle: windowTitle.replace(/\s[—–-]\s.*$/, "").trim()

    readonly property color accentColor: iconColors.dominant.hslSaturation > 0.1
        ? iconColors.dominant
        : Kirigami.Theme.highlightColor

    // --- Logic: State Synchronization ---
    function updateState() {
        // Block updates if we are currently hovering (preventing focus-grab loops)
        if (!tasksModel || ignoreUpdates) return;
        
        let foundActive = -1;
        let count = 0;
        
        for (let i = 0; i < tasksModel.rowCount(); ++i) {
            const idx = tasksModel.index(i, 0);
            const isActive = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive);
            if (isActive) {
                foundActive = i;
            } else {
                count++;
            }
        }
        
        pill.activeIndex = foundActive;
        pill.otherCount = count;
    }

    Connections {
        target: pill.tasksModel
        function onDataChanged() { pill.updateState(); }
        function onRowsInserted() { pill.updateState(); }
        function onRowsRemoved() { pill.updateState(); }
        function onModelReset() { pill.updateState(); }
    }

    Component.onCompleted: updateState()

    // --- UI Styling ---
    Kirigami.ImageColors {
        id: iconColors
        source: pill.taskIcon || "application-x-executable"
    }

    color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
    border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.45)
    border.width: 1
    radius: height / 2

    implicitHeight: Kirigami.Units.gridUnit * 1.4
    implicitWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
    
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }

    clip: true 
    opacity: 1.0

    Accessible.role: Accessible.Button
    Accessible.name: appName + (shortTitle ? " · " + shortTitle : "")

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: pill.taskIcon
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        QQC2.Label {
            id: appLabel
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
            id: titleLabel
            text: pill.shortTitle
            opacity: 0.7
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            visible: pill.shortTitle.length > 0
        }

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
        
        onEntered: {
            pill.ignoreUpdates = true;
            pill.hoverEnter();
        }
        
        onExited: {
            pill.ignoreUpdates = false;
            // Catch up on any changes that happened while we were ignoring them
            pill.updateState();
            pill.hoverLeave();
        }
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                pill.closeActive();
        }
    }
}