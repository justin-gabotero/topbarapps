pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager

PlasmaExtras.Menu {
    id: menu

    property var backend: null
    required property var tasksModel
    required property var modelIndex
    property bool destroyOnClose: true
    readonly property bool menuOpen: status !== PlasmaExtras.Menu.Closed

    readonly property var atm: TaskManager.AbstractTasksModel
    property bool populated: false
    property bool autoOpen: false

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
            if (destroyOnClose)
                destroy();
        }
    }

    Component.onCompleted: {
        if (autoOpen) {
            show();
        }
    }

    function get(role: int): var {
        return tasksModel.data(modelIndex, role);
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

    function addSeparator(): void {
        const item = Qt.createQmlObject(
            "import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem { separator: true }",
            menu
        );
        addMenuItem(item);
    }

    function addHeader(text: string): void {
        const item = newMenuItem(menu);
        item.text = text;
        item.section = true;
        addMenuItem(item);
    }

    function addQAction(action: var): void {
        if (!action || !action.text) {
            return;
        }
        const item = newMenuItem(menu);
        item.action = action;
        addMenuItem(item);
    }

    function activateModelIndex(index: var): void {
        if (tasksModel.data(index, atm.IsMinimized)) {
            tasksModel.requestToggleMinimized(index);
        }
        tasksModel.requestActivate(index);
    }

    function populateWindowChooser(windowChooserMenu: PlasmaExtras.Menu): void {
        windowChooserMenu.clearMenuItems();

        const childCount = tasksModel.rowCount(modelIndex);
        for (let i = 0; i < childCount; ++i) {
            const childIndex = tasksModel.makeModelIndex(modelIndex, i);
            const windowItem = newMenuItem(windowChooserMenu);
            windowItem.text = String(tasksModel.data(childIndex, Qt.DisplayRole) || tasksModel.data(childIndex, atm.AppName) || qsTr("Window %1").arg(i + 1));
            windowItem.icon = tasksModel.data(childIndex, Qt.DecorationRole);
            windowItem.clicked.connect(() => activateModelIndex(childIndex));
            windowChooserMenu.addMenuItem(windowItem);
        }
    }

    readonly property Component windowChooserItemComponent: Component {
        PlasmaExtras.MenuItem {
            id: chooseWindowItem

            text: qsTr("Activate Window")
            icon: "view-list-tree"

            readonly property PlasmaExtras.Menu _windowChooserMenu: PlasmaExtras.Menu {
                id: windowChooserMenu

                visualParent: chooseWindowItem

                function refresh(): void {
                    menu.populateWindowChooser(windowChooserMenu);
                }

                Component.onCompleted: refresh()
            }
        }
    }

    function populate(): void {
        if (populated) {
            return;
        }
        populated = true;

        let hasAnyItems = false;
        let hasDynamicItems = false;

        const isWindow = !!get(atm.IsWindow);
        const isGroup = !!get(atm.IsGroupParent);
        const canNewInstance = !!get(atm.CanLaunchNewInstance);
        const childCount = tasksModel.rowCount(modelIndex);

        if (isWindow || isGroup) {
            const activateItem = newMenuItem(menu);
            activateItem.text = qsTr("Activate");
            activateItem.icon = "window-restore";
            activateItem.clicked.connect(() => activateModelIndex(modelIndex));
            addMenuItem(activateItem);
            hasAnyItems = true;
        }

        if (isGroup && childCount > 1) {
            const chooseWindowItem = windowChooserItemComponent.createObject(menu);
            addMenuItem(chooseWindowItem);
            hasAnyItems = true;
        }

        if (canNewInstance) {
            const newInstanceItem = newMenuItem(menu);
            newInstanceItem.text = qsTr("Open New Window");
            newInstanceItem.icon = "window-new";
            newInstanceItem.clicked.connect(() => tasksModel.requestNewInstance(modelIndex));
            addMenuItem(newInstanceItem);
            hasAnyItems = true;
        }

        const launcherUrl = get(atm.LauncherUrlWithoutIcon);
        const hasLauncher = launcherUrl && launcherUrl.toString() !== "";

        if (hasLauncher) {
            const isPinned = tasksModel.launcherList.some(l => l === launcherUrl.toString())
                || !!get(atm.IsLauncher);
            const pinItem = newMenuItem(menu);
            pinItem.text = isPinned ? qsTr("Unpin from List") : qsTr("Pin to List");
            pinItem.icon = isPinned ? "window-unpin" : "window-pin";
            pinItem.clicked.connect(() => {
                if (isPinned) {
                    tasksModel.requestRemoveLauncher(launcherUrl);
                } else {
                    tasksModel.requestAddLauncher(launcherUrl);
                }
            });
            addMenuItem(pinItem);
            hasAnyItems = true;
        }

        if (hasLauncher && backend) {
            try {
                const placesActions = backend.placesActions(launcherUrl, false, menu);
                const recentActions = backend.recentDocumentActions(launcherUrl, menu);
                const jumpActions = backend.jumpListActions(launcherUrl, menu);

                if (placesActions.length > 0) {
                    addSeparator();
                    addHeader(qsTr("Places"));
                    for (let i = 0; i < placesActions.length; ++i) {
                        addQAction(placesActions[i]);
                    }
                    hasAnyItems = true;
                    hasDynamicItems = true;
                } else if (recentActions.length > 0) {
                    addSeparator();
                    addHeader(qsTr("Recent Files"));
                    for (let i = 0; i < recentActions.length; ++i) {
                        addQAction(recentActions[i]);
                    }
                    hasAnyItems = true;
                    hasDynamicItems = true;
                }

                if (jumpActions.length > 0) {
                    addSeparator();
                    addHeader(qsTr("Actions"));
                    for (let i = 0; i < jumpActions.length; ++i) {
                        addQAction(jumpActions[i]);
                    }
                    hasAnyItems = true;
                    hasDynamicItems = true;
                }
            } catch (error) {
                console.warn("TaskContextMenu dynamic actions failed", error);
            }
        }

        if (isWindow || isGroup) {
            if (hasAnyItems) {
                addSeparator();
            }
            const closeItem = newMenuItem(menu);
            closeItem.text = isGroup ? qsTr("Close All Windows") : qsTr("Close");
            closeItem.icon = "window-close";
            closeItem.clicked.connect(() => tasksModel.requestClose(modelIndex));
            addMenuItem(closeItem);
            hasAnyItems = true;
        } /* else {
            // Always provide at least one useful default action.
            const closeItem = newMenuItem(menu);
            closeItem.text = i18n("Close");
            closeItem.icon = "window-close";
            closeItem.enabled = false;
            addMenuItem(closeItem);
            hasAnyItems = true;
        } */
    }

    function show(): void {
        clearMenuItems();
        populated = false;
        populate();
        openRelative();
    }
}
