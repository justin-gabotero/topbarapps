pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Item {
    id: arc

    property TaskManager.TasksModel tasksModel
    property int activeIndex: -1
    property int otherCount: 0
    property int step: 160
    property bool open: false
    property real sidePadding: 2

    // Vertical drop per slot away from center (creates the arc curve)
    readonly property real arcStepY: 10
    readonly property real nodeHeight: Kirigami.Units.gridUnit * 1.3
    readonly property real topMargin: Kirigami.Units.smallSpacing
    readonly property var otherRows: {
        const rows = [];
        if (!arc.tasksModel)
            return rows;

        for (let i = 0; i < arc.tasksModel.count; ++i) {
            const idx = arc.tasksModel.index(i, 0);
            if (!arc.tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive))
                rows.push(i);
        }
        return rows;
    }
    readonly property int visibleCount: otherRows.length
    readonly property real arcTotalDrop: arc.arcStepY * Math.floor(arc.visibleCount / 2)

    signal hoverEnter()
    signal hoverLeave()
    signal activate(int row)
    signal close(int row)
    signal contextMenu(int row, var sourceItem)

    implicitWidth: (arc.step * Math.max(arc.visibleCount, 1)) + arc.sidePadding * 2
    implicitHeight: arc.nodeHeight + arc.arcTotalDrop + arc.topMargin + Kirigami.Units.smallSpacing

    // Topmost hover sentinel — acceptedButtons:Qt.NoButton lets clicks fall through
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 1
        onEntered: arc.hoverEnter()
        onExited: arc.hoverLeave()
    }

    Repeater {
        model: arc.visibleCount

        delegate: OrbitNode {
            id: node
            required property int index
            readonly property int taskModelRow: arc.otherRows[index]
            readonly property var taskIndex: arc.tasksModel.index(taskModelRow, 0)
            readonly property bool isMinimizedTask: arc.tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized) === true

            readonly property int slotIndex: arc.visibleCount - 1 - index

            // Distance from the center slot — drives the arc Y curve
            readonly property real centerSlot: (arc.visibleCount - 1) / 2
            readonly property real distFromCenter: Math.abs(slotIndex - centerSlot)

            // Arc Y: center nodes sit highest (closest to pill), edges drop down
            readonly property real arcY: arc.topMargin + distFromCenter * arc.arcStepY

            nodeWidth: arc.step

            taskRow: taskModelRow
            taskTitle: String(arc.tasksModel.data(taskIndex, Qt.DisplayRole) || "")
            taskApp: String(arc.tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppName) || "")
            taskIcon: arc.tasksModel.data(taskIndex, Qt.DecorationRole)
            minimized: isMinimizedTask

            x: arc.sidePadding + slotIndex * arc.step
            y: arc.open ? arcY : -(arc.nodeHeight + arc.topMargin)
            opacity: arc.open ? 1.0 : 0.0
            scale: arc.open ? 1.0 : 0.85

            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.6
                }
            }
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: arc.open ? node.slotIndex * 20 : 0 }
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            onActivate: arc.activate(node.taskRow)
            onClose: arc.close(node.taskRow)
            onOpenContextMenu: (sourceItem) => arc.contextMenu(node.taskRow, sourceItem)
        }
    }
}
