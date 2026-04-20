import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.minimumWidth: Kirigami.Units.gridUnit * 2
    Layout.preferredWidth: pill.implicitWidth

    // ── Task model ────────────────────────────────────────────────────────────

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModelObj
        filterByVirtualDesktop: Plasmoid.configuration.filterCurrentDesktopOnly
        filterByScreen: true
        filterByActivity: true
        filterNotMinimized: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
        separateLaunchers: false
        hideActivatedLaunchers: true
    }

    // ── Derived state ─────────────────────────────────────────────────────────

    readonly property int activeIndex: {
        for (let i = 0; i < tasksModel.count; i++) {
            if (tasksModel.data(tasksModel.index(i, 0), TaskManager.AbstractTasksModel.IsActive))
                return i;
        }
        return -1;
    }

    readonly property int otherCount: Math.max(0, tasksModel.count - (activeIndex >= 0 ? 1 : 0))

    // ── Hover open/close ──────────────────────────────────────────────────────

    property bool arcOpen: false
    property bool arcWasHovered: false
    property bool pillHovered: false
    property bool arcHovered: false
    property bool arcLockedOpen: false

    // 300 ms hold on pill before arc opens
    Timer {
        id: openTimer
        interval: 300
        onTriggered: root.arcOpen = true
    }

    // Arc must be hovered for the configured dwell time before it is considered "locked" open.
    Timer {
        id: engageTimer
        interval: Plasmoid.configuration.hoverCloseDelayMs
        onTriggered: {
            if (root.arcOpen && root.arcHovered) {
                root.arcLockedOpen = true;
            } else if (!root.pillHovered && !root.arcHovered) {
                closeTimer.restart();
            }
        }
    }

    // Configured delay before arc closes after cursor leaves the arc
    Timer {
        id: closeTimer
        interval: Plasmoid.configuration.hoverCloseDelayMs
        onTriggered: {
            if (!root.pillHovered && !root.arcHovered) {
                root.arcOpen = false;
            }
        }
    }

    onArcOpenChanged: {
        if (arcOpen) {
            root.arcLockedOpen = false;
            engageTimer.restart();
        } else {
            root.arcWasHovered = false;
            root.arcHovered = false;
            root.arcLockedOpen = false;
            engageTimer.stop();
            closeTimer.stop();
        }
    }

    function onPillEnter() {
        root.pillHovered = true;
        closeTimer.stop();
        if (!root.arcOpen) openTimer.restart();
    }
    function onPillLeave() {
        root.pillHovered = false;
        openTimer.stop();

        if (!root.arcOpen || root.arcHovered)
            return;

        if (!engageTimer.running && !root.arcLockedOpen)
            closeTimer.restart();
    }
    function onArcEnter() {
        root.arcHovered = true;
        closeTimer.stop();
        root.arcWasHovered = true;

        if (!root.arcLockedOpen)
            engageTimer.restart();
    }
    function onArcLeave() {
        root.arcHovered = false;

        if (!root.pillHovered)
            closeTimer.restart();
    }

    // ── Window actions ────────────────────────────────────────────────────────

    function activateRow(row) {
        const idx = tasksModel.index(row, 0);
        if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized))
            tasksModel.requestToggleMinimized(idx);
        tasksModel.requestActivate(idx);
    }

    function closeRow(row) {
        tasksModel.requestClose(tasksModel.index(row, 0));
    }

    function showNodeContextMenu(row, sourceItem) {
        const idx = tasksModel.index(row, 0);
        if (!idx.valid)
            return;

        const menu = taskContextMenuComponent.createObject(root, {
            autoOpen: true,
            visualParent: sourceItem,
            tasksModel: root.tasksModel,
            modelIndex: idx
        });
    }

    Component {
        id: taskContextMenuComponent
        TaskContextMenu {}
    }

    // ── Widget body ───────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent

        CurrentPill {
            id: pill
            anchors.fill: parent
            tasksModel: root.tasksModel
            activeIndex: root.activeIndex
            otherCount: root.otherCount
            onHoverEnter: root.onPillEnter()
            onHoverLeave: root.onPillLeave()
            onCloseActive: {
                if (root.activeIndex >= 0) root.closeRow(root.activeIndex);
            }
        }
    }

    // ── Arc popup ─────────────────────────────────────────────────────────────

    PlasmaCore.PopupPlasmaWindow {
        id: arcPopup
        visualParent: pill
        visible: root.arcOpen && root.otherCount > 0
        modality: Qt.NonModal
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

        popupDirection: switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge:   return Qt.BottomEdge
            case PlasmaCore.Types.LeftEdge:  return Qt.RightEdge
            case PlasmaCore.Types.RightEdge: return Qt.LeftEdge
            default:                         return Qt.TopEdge
        }

        width: orbitArc.implicitWidth + leftPadding + rightPadding
        height: orbitArc.implicitHeight + topPadding + bottomPadding

        mainItem: OrbitArc {
            id: orbitArc
            width: implicitWidth
            height: implicitHeight

            tasksModel: root.tasksModel
            activeIndex: root.activeIndex
            otherCount: root.otherCount
            step: Plasmoid.configuration.nodeStepPx
            open: root.arcOpen && arcPopup.visible

            onHoverEnter: root.onArcEnter()
            onHoverLeave: root.onArcLeave()
            onActivate: (row) => { root.activateRow(row); root.arcOpen = false; }
            onClose: (row) => root.closeRow(row)
            onContextMenu: (row, sourceItem) => root.showNodeContextMenu(row, sourceItem)
        }
    }
}
