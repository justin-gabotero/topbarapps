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

    function isLauncherLike(row: int): bool {
        return !!taskData(row, TaskManager.AbstractTasksModel.IsLauncher)
            || !!taskData(row, TaskManager.AbstractTasksModel.IsStartup);
    }

    function isVisibleTaskRow(row: int): bool {
        if (isLauncherLike(row)) {
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
        if (!isGroupTask(row)) {
            return "";
        }
        const count = childCountFor(row);
        return count > 1 ? i18n("%1 windows", count) : i18n("%1 window", count);
    }

    function visibleTaskCount(): int {
        let count = 0;
        for (let i = 0; i < tasksModel.count; ++i) {
            if (!isVisibleTaskRow(i)) {
                continue;
            }
            if (isGroupTask(i)) {
                count += childCountFor(i);
            } else {
                ++count;
            }
        }
        return count;
    }

    function rebuildVisibleRows(): void {
        visibleRowsModel.clear();
        for (let i = 0; i < tasksModel.count; ++i) {
            if (!isVisibleTaskRow(i)) {
                continue;
            }
            visibleRowsModel.append({ sourceRow: i });
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

        const menu = component.createObject(root, {
            tasksModel: tasksModel,
            parentRow: row,
            visualParent: sourceItem
        });
        if (!menu) {
            console.warn("Failed to create task window chooser");
            activateTask(row);
            return;
        }
        menu.show();
    }

    function activateTask(row: int): void {
        const idx = modelIndexFor(row);

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

        const menu = component.createObject(root, {
            backend: backend,
            tasksModel: tasksModel,
            modelIndex: modelIndexFor(row),
            visualParent: sourceItem
        });
        if (!menu) {
            console.warn("Failed to create task context menu");
            return;
        }
        menu.show();
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.minimumWidth: Kirigami.Units.gridUnit * 2
    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
    Layout.maximumWidth: Kirigami.Units.gridUnit * 3

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

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
        target: tasksModel

        function onCountChanged(): void {
            root.refreshUiFromModel();
        }

        function onDataChanged(): void {
            root.refreshUiFromModel();
        }

        function onActiveTaskChanged(): void {
            root.refreshUiFromModel();
        }
    }

    Component.onCompleted: refreshUiFromModel()

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

        removeBorderStrategy: Plasmoid.location === PlasmaCore.Types.Floating
            ? PlasmaCore.AppletPopup.AtScreenEdges
            : PlasmaCore.AppletPopup.AtScreenEdges | PlasmaCore.AppletPopup.AtPanelEdges

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

                delegate: TaskDropdownRow {
                    required property int sourceRow

                    property int taskRow: sourceRow

                    width: listView.width
                    height: implicitHeight
                    visible: true

                    title: root.rowTitle(taskRow)
                    secondaryText: root.rowSecondaryText(taskRow)
                    iconSource: root.taskData(taskRow, Qt.DecorationRole)
                    active: !!root.taskData(taskRow, TaskManager.AbstractTasksModel.IsActive)

                    onClicked: sourceItem => root.showWindowChooser(taskRow, sourceItem)
                    onRightClicked: sourceItem => root.showContextMenu(taskRow, sourceItem)
                }
            }
        }
    }
}
