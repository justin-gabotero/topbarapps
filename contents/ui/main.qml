pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.taskmanager as TaskManagerApplet

PlasmoidItem {
    id: root

    readonly property int maxVisibleRows: Math.max(3, Plasmoid.configuration.maxVisibleRows)
    readonly property string triggerIconName: Plasmoid.configuration.triggerIcon || "view-list-tree"

    function showDynamicMenu(menuObj: var): void {
        if (menuObj) {
            menuObj.show();
        }
    }

    function modelIndexFor(row: int): var {
        return tasksModel.makeModelIndex(row);
    }

    function taskData(row: int, role: int): var {
        return tasksModel.data(modelIndexFor(row), role);
    }

    function isGroupTask(row: int): bool {
        return !!taskData(row, TaskManager.AbstractTasksModel.IsGroupParent);
    }

    function childCountFor(row: int): int {
        return Number(taskData(row, TaskManager.AbstractTasksModel.ChildCount)) || 0;
    }

    function isWindowTask(row: int): bool {
        return !!taskData(row, TaskManager.AbstractTasksModel.IsWindow);
    }

    function isTaskRunning(row: int): bool {
        return isWindowTask(row) || isGroupTask(row);
    }

    function isPinnedRow(row: int): bool {
        return !!taskData(row, TaskManager.AbstractTasksModel.IsLauncher);
    }

    function isTaskPinned(row: int): bool {
        const url = taskData(row, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
        if (!url) return false;
        const urlStr = url.toString();
        return tasksModel.launcherList.some(l => l === urlStr);
    }

    function savePinnedConfig(): void {
        Plasmoid.configuration.pinnedOrder = JSON.stringify(tasksModel.launcherList);
    }

    function togglePin(row: int): void {
        const url = taskData(row, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
        if (!url || url.toString() === "") return;
        if (isTaskPinned(row) || isPinnedRow(row)) {
            tasksModel.requestRemoveLauncher(url);
        } else {
            tasksModel.requestAddLauncher(url);
        }
    }

    function isVisibleTaskRow(row: int): bool {
        // Show pinned launchers (not transient startup entries)
        if (taskData(row, TaskManager.AbstractTasksModel.IsLauncher)) {
            return true;
        }
        if (taskData(row, TaskManager.AbstractTasksModel.IsStartup)) {
            return false;
        }
        if (isGroupTask(row)) {
            return childCountFor(row) > 0;
        }
        return isWindowTask(row);
    }

    function rowTitle(row: int): string {
        const appName = taskData(row, TaskManager.AbstractTasksModel.AppName);
        const display = taskData(row, Qt.DisplayRole);
        return String(appName || display || "");
    }

    function rowSecondaryText(row: int): string {
        if (isPinnedRow(row)) {
            return "";
        }
        if (!isGroupTask(row)) {
            return "";
        }
        const count = childCountFor(row);
        return count > 1 ? qsTr("%1 windows").arg(count) : qsTr("%1 window").arg(count);
    }

    function visibleTaskCount(): int {
        let count = 0;
        for (let i = 0; i < tasksModel.count; ++i) {
            if (!isVisibleTaskRow(i)) {
                continue;
            }
            if (isPinnedRow(i)) {
                count += 1;
            } else if (isGroupTask(i)) {
                count += childCountFor(i);
            } else {
                ++count;
            }
        }
        return count;
    }

    function isRowPinned(row: int): bool {
        return isPinnedRow(row) || isTaskPinned(row);
    }

    function rebuildVisibleRows(): void {
        visibleRowsModel.clear();
        // All pinned items first — both not-running launchers and running pinned tasks.
        for (let i = 0; i < tasksModel.count; ++i) {
            if (isVisibleTaskRow(i) && isRowPinned(i)) {
                visibleRowsModel.append({ sourceRow: i });
            }
        }
        // Unpinned running tasks below.
        for (let i = 0; i < tasksModel.count; ++i) {
            if (isVisibleTaskRow(i) && !isRowPinned(i)) {
                visibleRowsModel.append({ sourceRow: i });
            }
        }
    }

    // Count how many of the current visible rows are pinned.
    function visiblePinnedCount(): int {
        let count = 0;
        for (let i = 0; i < visibleRowsModel.count; ++i) {
            if (isRowPinned(visibleRowsModel.get(i).sourceRow)) {
                count++;
            }
        }
        return count;
    }

    // After reordering pinned items, write the new order back to launcherList
    // so it survives closing and reopening the dropdown (and shell restarts).
    function persistPinnedOrder(): void {
        const urls = [];
        for (let i = 0; i < visibleRowsModel.count; ++i) {
            const row = visibleRowsModel.get(i).sourceRow;
            if (!isPinnedRow(row)) continue;
            const url = taskData(row, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
            if (url && url.toString()) {
                urls.push(url.toString());
            }
        }
        if (urls.length > 0) {
            tasksModel.launcherList = urls;
        }
    }

    function refreshUiFromModel(): void {
        rebuildVisibleRows();
        if (root.windowCount === 0) {
            dropdown.visible = false;
        }
    }

    function togglePopup(): void {
        if (windowCount === 0) {
            dropdown.visible = false;
            return;
        }
        dropdown.visible = !dropdown.visible;
        if (dropdown.visible) {
            dropdown.requestActivate();
        }
    }

    function showWindowChooser(row: int, sourceItem: Item): void {
        const childCount = tasksModel.rowCount(modelIndexFor(row));
        if (childCount <= 1) {
            activateTask(row);
            return;
        }

        const component = Qt.createComponent("TaskWindowChooser.qml");
        if (component.status !== Component.Ready) {
            console.warn("Failed to load TaskWindowChooser.qml", component.errorString());
            activateTask(row);
            return;
        }

        var menu = component.createObject(root, {
            tasksModel: tasksModel,
            parentRow: row,
            visualParent: sourceItem
        });
        if (!menu) {
            console.warn("Failed to create task window chooser");
            activateTask(row);
            return;
        }
        root.showDynamicMenu(menu);
    }

    function activateTask(row: int): void {
        const idx = modelIndexFor(row);

        // Pinned launcher: just activate (launches if not running)
        if (isPinnedRow(row)) {
            tasksModel.requestActivate(idx);
            dropdown.visible = false;
            return;
        }

        if (isGroupTask(row)) {
            const childTotal = tasksModel.rowCount(idx);
            if (childTotal > 0) {
                let targetChild = tasksModel.makeModelIndex(row, 0);
                let bestStacking = -1;

                // Prefer the currently active child in the group; otherwise pick most recently used.
                for (let i = 0; i < childTotal; ++i) {
                    const childIdx = tasksModel.makeModelIndex(row, i);
                    if (tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive)) {
                        targetChild = childIdx;
                        bestStacking = Number.MAX_SAFE_INTEGER;
                        break;
                    }

                    const stacking = Number(tasksModel.data(childIdx, TaskManager.AbstractTasksModel.StackingOrder)) || 0;
                    if (stacking > bestStacking) {
                        bestStacking = stacking;
                        targetChild = childIdx;
                    }
                }

                if (tasksModel.data(targetChild, TaskManager.AbstractTasksModel.IsMinimized)) {
                    tasksModel.requestToggleMinimized(targetChild);
                }
                tasksModel.requestActivate(targetChild);
                dropdown.visible = false;
                return;
            }
        }

        if (taskData(row, TaskManager.AbstractTasksModel.IsMinimized)) {
            tasksModel.requestToggleMinimized(idx);
        }
        tasksModel.requestActivate(idx);
        dropdown.visible = false;
    }

    function showContextMenu(row: int, sourceItem: Item): void {
        const component = Qt.createComponent("TaskContextMenu.qml");
        if (component.status !== Component.Ready) {
            console.warn("Failed to load TaskContextMenu.qml", component.errorString());
            return;
        }

        var menu = component.createObject(root, {
            backend: backend,
            tasksModel: tasksModel,
            modelIndex: modelIndexFor(row),
            visualParent: sourceItem
        });
        if (!menu) {
            console.warn("Failed to create task context menu");
            return;
        }
        root.showDynamicMenu(menu);
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.minimumWidth: Kirigami.Units.gridUnit * 2
    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
    Layout.maximumWidth: Kirigami.Units.gridUnit * 3

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModelObj

        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterNotMinimized: false

        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortLastActivated
        separateLaunchers: true
        hideActivatedLaunchers: true
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {}

    readonly property int windowCount: visibleTaskCount()

    ListModel {
        id: visibleRowsModel
    }

    Connections {
        target: root.tasksModel

        function onCountChanged(): void {
            root.refreshUiFromModel();
        }

        function onDataChanged(): void {
            root.refreshUiFromModel();
        }

        function onLauncherListChanged(): void {
            root.savePinnedConfig();
        }

        function onActiveTaskChanged(): void {
            root.refreshUiFromModel();
            // Close only when a window actually gains focus (not when all windows
            // lose focus, e.g. when the dropdown itself opens).
            if (dropdown.visible) {
                for (let i = 0; i < root.tasksModel.count; ++i) {
                    if (root.taskData(i, TaskManager.AbstractTasksModel.IsActive)) {
                        dropdown.visible = false;
                        break;
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // Restore pinned launchers saved from a previous session.
        try {
            const saved = JSON.parse(Plasmoid.configuration.pinnedOrder || "[]");
            for (const url of saved) {
                if (url) tasksModel.requestAddLauncher(url);
            }
        } catch (e) {
            console.warn("Failed to restore pinned apps:", e);
        }
        refreshUiFromModel();
    }

    Item {
        anchors.fill: parent

        PlasmaComponents3.ToolButton {
            id: triggerButton
            anchors.fill: parent
            icon.name: root.triggerIconName
            text: ""
            onClicked: root.togglePopup()
        }
    }

    PlasmaCore.PopupPlasmaWindow {
        id: dropdown

        visible: false
        animated: true
        visualParent: triggerButton

        width: Math.max(Kirigami.Units.gridUnit * 16, triggerButton.width * 8)
        height: Math.min(Kirigami.Units.gridUnit * root.maxVisibleRows, listView.contentHeight) + topPadding + bottomPadding

        popupDirection: switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge:
                return Qt.BottomEdge
            case PlasmaCore.Types.LeftEdge:
                return Qt.RightEdge
            case PlasmaCore.Types.RightEdge:
                return Qt.LeftEdge
            default:
                return Qt.TopEdge
        }

        onActiveChanged: {
            if (!active) {
                visible = false;
            }
        }

        mainItem: PlasmaComponents3.ScrollView {
            id: listScrollView
            clip: true

            ListView {
                id: listView
                implicitWidth: dropdown.width - listScrollView.leftPadding - listScrollView.rightPadding
                model: visibleRowsModel
                reuseItems: false
                spacing: Kirigami.Units.smallSpacing / 2

                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Item {
                    id: delegateItem
                    required property int index
                    required property int sourceRow

                    width: listView.width
                    height: taskRow.implicitHeight

                    property int taskModelRow: sourceRow
                    property int dragFromIndex: -1

                    // Reparent to listView while dragging so the item floats freely.
                    states: State {
                        when: dragHandle.drag.active
                        ParentChange {
                            target: delegateItem
                            parent: listView
                        }
                        AnchorChanges {
                            target: delegateItem
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: undefined
                        }
                    }

                    TaskDropdownRow {
                        id: taskRow
                        width: delegateItem.width
                        title: root.rowTitle(delegateItem.taskModelRow)
                        secondaryText: root.rowSecondaryText(delegateItem.taskModelRow)
                        iconSource: root.taskData(delegateItem.taskModelRow, Qt.DecorationRole)
                        active: !!root.taskData(delegateItem.taskModelRow, TaskManager.AbstractTasksModel.IsActive)
                        running: root.isTaskRunning(delegateItem.taskModelRow)
                        pinned: root.isRowPinned(delegateItem.taskModelRow)
                        dragging: dragHandle.drag.active

                        onClicked: sourceItem => root.showWindowChooser(delegateItem.taskModelRow, sourceItem)
                        onRightClicked: sourceItem => root.showContextMenu(delegateItem.taskModelRow, sourceItem)
                    }

                    // Drag handle — press and move to reorder
                    MouseArea {
                        id: dragHandle

                        property int pinnedCount: 0
                        property bool itemIsPinned: false

                        width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
                        height: parent.height
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing

                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : (containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)

                        drag.target: delegateItem
                        drag.axis: Drag.YAxis
                        // Constrain drag within the same group (pinned vs running)
                        // so pins never sink below running tasks and vice-versa.
                        drag.minimumY: dragHandle.itemIsPinned
                            ? 0
                            : dragHandle.pinnedCount * (delegateItem.height + listView.spacing)
                        drag.maximumY: dragHandle.itemIsPinned
                            ? Math.max(0, dragHandle.pinnedCount - 1) * (delegateItem.height + listView.spacing)
                            : listView.contentHeight - delegateItem.height

                        onPressed: {
                            delegateItem.dragFromIndex = delegateItem.index;
                            dragHandle.pinnedCount = root.visiblePinnedCount();
                            dragHandle.itemIsPinned = root.isRowPinned(delegateItem.taskModelRow);
                        }

                        onReleased: {
                            if (!drag.active) {
                                return;
                            }
                            const rowHeight = delegateItem.height + listView.spacing;
                            const centreY = delegateItem.y + delegateItem.height / 2;
                            let toIndex = Math.max(0, Math.min(
                                visibleRowsModel.count - 1,
                                Math.floor(centreY / rowHeight)
                            ));

                            // Hard-clamp: pinned items stay in the pinned section,
                            // unpinned items stay below it — regardless of where
                            // the cursor ended up (drag constraints can drift after
                            // the parent-change state transition).
                            if (dragHandle.itemIsPinned) {
                                toIndex = Math.min(toIndex, dragHandle.pinnedCount - 1);
                            } else {
                                toIndex = Math.max(toIndex, dragHandle.pinnedCount);
                            }

                            // Reset position BEFORE moving the model.
                            delegateItem.x = 0;
                            delegateItem.y = 0;

                            if (toIndex !== delegateItem.dragFromIndex && delegateItem.dragFromIndex >= 0) {
                                visibleRowsModel.move(delegateItem.dragFromIndex, toIndex, 1);
                                // Persist new pin order so it survives reopening.
                                if (dragHandle.itemIsPinned) {
                                    root.persistPinnedOrder();
                                }
                            }
                            delegateItem.dragFromIndex = -1;
                        }
                    }
                }
            }
        }
    }
}
