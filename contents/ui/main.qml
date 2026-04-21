pragma ComponentBehavior: Bound

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
        screenGeometry: Plasmoid.containment.screenGeometry
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

    readonly property int orbitCount: tasksModel.count
    readonly property int orbitGroupCount: {
        const grouped = {};
        let count = 0;
        for (let i = 0; i < tasksModel.count; ++i) {
            const idx = tasksModel.index(i, 0);
            const appName = String(tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || qsTr("Unknown App"));
            const key = appName.toLowerCase();
            if (!grouped[key]) {
                grouped[key] = true;
                count += 1;
            }
        }
        return count;
    }
    readonly property int otherCount: Math.max(0, tasksModel.count - (activeIndex >= 0 ? 1 : 0))
    readonly property real containmentScreenWidth: (Plasmoid.containment && Plasmoid.containment.screenGeometry.width > 0)
        ? Plasmoid.containment.screenGeometry.width
        : 1920
    readonly property real popupOuterMargin: Kirigami.Units.gridUnit
    readonly property real maxPopupWidth: Math.max(Kirigami.Units.gridUnit * 8, containmentScreenWidth - popupOuterMargin * 2)
    readonly property real estimatedPopupSidePadding: Kirigami.Units.largeSpacing * 2
    readonly property int arcStepPx: Plasmoid.configuration.nodeStepPx
    readonly property real arcImplicitWidth: Math.min(
        (arcStepPx * Math.max(orbitGroupCount, 1)) + 4,
        maxPopupWidth
    )
    readonly property real arcImplicitHeight: (Kirigami.Units.gridUnit * 1.3) + (Kirigami.Units.smallSpacing * 2)

    // ── Hover open/close ──────────────────────────────────────────────────────

    property bool arcOpen: false
    property bool arcWasHovered: false
    property bool pillHovered: false
    property bool arcHovered: false
    property bool arcLockedOpen: false
    readonly property bool contextMenuOpen: nodeContextMenu.menuOpen

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
            if (!root.pillHovered && !root.arcHovered && !root.contextMenuOpen) {
                root.arcOpen = false;
            }
        }
    }

    onContextMenuOpenChanged: {
        if (contextMenuOpen) {
            closeTimer.stop();
            return;
        }

        if (arcOpen && !pillHovered && !arcHovered)
            closeTimer.restart();
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

        if (!engageTimer.running && !root.arcLockedOpen && !root.contextMenuOpen)
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

        if (!root.pillHovered && !root.contextMenuOpen)
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

        nodeContextMenu.visualParent = sourceItem;
        nodeContextMenu.modelIndex = idx;
        nodeContextMenu.autoOpen = false;
        nodeContextMenu.show();
    }

    TaskContextMenu {
        id: nodeContextMenu
        tasksModel: root.tasksModel
        modelIndex: root.tasksModel.index(0, 0)
        autoOpen: false
        destroyOnClose: false
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

    PlasmaCore.Dialog {
        id: arcPopup
        visualParent: pill
        visible: root.arcOpen && root.orbitCount > 0
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Types.NoBackground

        location: switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge:   return PlasmaCore.Types.TopEdge
            case PlasmaCore.Types.LeftEdge:  return PlasmaCore.Types.LeftEdge
            case PlasmaCore.Types.RightEdge: return PlasmaCore.Types.RightEdge
            default:                         return PlasmaCore.Types.BottomEdge
        }

        mainItem: Loader {
            id: arcLoader
            width: Math.min(root.arcImplicitWidth, root.maxPopupWidth)
            height: root.arcImplicitHeight
            active: arcPopup.visible
            asynchronous: false

            sourceComponent: OrbitArc {
                width: parent.width
                height: parent.height

                tasksModel: root.tasksModel
                activeIndex: root.activeIndex
                otherCount: root.otherCount
                step: root.arcStepPx
                //contentWidth: (root.arcStepPx * Math.max(root.otherCount, 1)) + 4
                open: arcLoader.active && arcPopup.visible

                onHoverEnter: root.onArcEnter()
                onHoverLeave: root.onArcLeave()
                onActivate: (row) => { root.activateRow(row); root.arcOpen = false; }
                onClose: (row) => root.closeRow(row)
                onContextMenu: (row, sourceItem) => root.showNodeContextMenu(row, sourceItem)
            }
        }
    }
}
