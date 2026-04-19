pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager

PlasmaExtras.Menu {
    id: menu

    required property var tasksModel
    required property int parentRow

    readonly property var atm: TaskManager.AbstractTasksModel
    property bool populated: false

    placement: {
        if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        }
        if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        }
        if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        }
        return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
    }

    minimumWidth: menuWidthFor(visualParent)

    onStatusChanged: {
        if (status === PlasmaExtras.Menu.Closed) {
            destroy();
        }
    }

    function menuWidthFor(obj: var): real {
        return (obj && obj["width"] !== undefined) ? Number(obj["width"]) : 0;
    }

    function newMenuItem(parent: QtObject): var {
        return Qt.createQmlObject(
            "import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}",
            parent
        );
    }

    function activateModelIndex(index: var): void {
        if (tasksModel.data(index, atm.IsMinimized)) {
            tasksModel.requestToggleMinimized(index);
        }
        tasksModel.requestActivate(index);
    }

    function populate(): void {
        if (populated) {
            return;
        }
        populated = true;

        const parentIndex = tasksModel.makeModelIndex(parentRow);
        const childCount = tasksModel.rowCount(parentIndex);
        for (let i = 0; i < childCount; ++i) {
            const childIndex = tasksModel.makeModelIndex(parentRow, i);
            const menuItem = newMenuItem(menu);
            menuItem.text = String(tasksModel.data(childIndex, Qt.DisplayRole) || tasksModel.data(childIndex, atm.AppName) || tasksModel.data(childIndex, atm.GenericName) || qsTr("Window %1").arg(i + 1));
            menuItem.icon = tasksModel.data(childIndex, Qt.DecorationRole);
            menuItem.clicked.connect(() => activateModelIndex(childIndex));
            addMenuItem(menuItem);
        }
    }

    function show(): void {
        populate();
        openRelative();
    }
}
