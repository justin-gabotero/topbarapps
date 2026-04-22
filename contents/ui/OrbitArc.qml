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
    property real nodeGap: Kirigami.Units.smallSpacing
    property bool open: false
    property real sidePadding: Kirigami.Units.smallSpacing 
    property real laneStep: arc.step + arc.nodeGap
    property real contentWidth: (arc.step * Math.max(arc.visibleCount, 1)) + (Math.max(arc.visibleCount - 1, 0) * arc.nodeGap) + (arc.sidePadding * 2)
    property bool ignoreUpdates: false

    readonly property real nodeHeight: Kirigami.Units.gridUnit * 1.6 
    readonly property real topMargin: Kirigami.Units.smallSpacing
    
    readonly property var groupedNodes: {
        const groups = [];
        const byApp = {};
        if (!arc.tasksModel) return groups;

        for (let i = 0; i < arc.tasksModel.rowCount(); ++i) {
            const idx = arc.tasksModel.index(i, 0);
            const appName = String(arc.tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || qsTr("Unknown App"));
            const key = appName.toLowerCase();

            if (!byApp[key]) {
                const group = {
                    appName: appName,
                    rows: [i],
                    icon: arc.tasksModel.data(idx, Qt.DecorationRole),
                    hasMinimized: arc.tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true
                };
                byApp[key] = group;
                groups.push(group);
            } else {
                byApp[key].rows.push(i);
                if (arc.tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true)
                    byApp[key].hasMinimized = true;
            }
        }

        return groups;
    }
    readonly property int visibleCount: groupedNodes.length

    signal hoverEnter()
    signal hoverLeave()
    signal activate(int row)
    signal close(int row)
    signal contextMenu(int row, var sourceItem)

    implicitWidth: contentWidth
    implicitHeight: arc.nodeHeight

    Rectangle {
        id: background
        anchors.fill: parent
        color: "#050c13"
        radius: Kirigami.Units.smallSpacing
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        z: 0 
        
        opacity: arc.open ? 1.0 : 0.0
        scale: arc.open ? 1.0 : 0.98
        
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                arc.ignoreUpdates = true;
                arc.hoverEnter();
            } else {
                arc.ignoreUpdates = false;
                arc.hoverLeave();
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: arc.contentWidth
        contentHeight: arc.height
        flickableDirection: Flickable.HorizontalFlick
        clip: true
        interactive: contentWidth > width
        focus: false 
        z: 1

        Behavior on contentX {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: arc.visibleCount

            delegate: OrbitNode {
                id: node
                required property int index
                focus: false
                
                readonly property var nodeGroup: (index >= 0 && index < arc.groupedNodes.length) ? arc.groupedNodes[index] : null
                readonly property var groupRows: nodeGroup ? nodeGroup.rows : []
                readonly property int taskModelRow: groupRows.length > 0 ? groupRows[0] : -1
                readonly property var taskIndex: taskModelRow >= 0 ? arc.tasksModel.index(taskModelRow, 0) : null
                readonly property bool isMinimizedTask: nodeGroup ? nodeGroup.hasMinimized : false
                readonly property int slotIndex: arc.visibleCount - 1 - index

                nodeWidth: arc.step
                taskRow: taskModelRow
                taskTitle: taskModelRow >= 0 ? String(arc.tasksModel.data(taskIndex, Qt.DisplayRole) || "") : ""
                taskApp: nodeGroup ? nodeGroup.appName : ""
                taskIcon: nodeGroup ? nodeGroup.icon : null
                windowCount: groupRows.length
                minimized: isMinimizedTask

                x: arc.sidePadding + (slotIndex * arc.laneStep)
                
                // Vertically center each node within the arc container.
                y: arc.open ? Math.max(0, (arc.height - height) / 2) : -height
                
                opacity: arc.open ? 1.0 : 0.0
                openScale: arc.open ? 1.0 : 0.85

                Behavior on y {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.2 // Minimal overshoot to prevent clipping
                    }
                }
                
                onActivate: arc.activate(node.taskRow)
                onClose: {
                    for (let i = groupRows.length - 1; i >= 0; --i)
                        arc.close(groupRows[i]);
                }
                onOpenContextMenu: (sourceItem) => arc.contextMenu(node.taskRow, sourceItem)
            }
        }
    }
}