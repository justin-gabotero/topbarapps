pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: root

    property alias cfg_maxVisibleRows: maxRowsSpin.value
    property alias cfg_triggerIcon: iconField.text

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents3.Label {
        text: "Maximum rows"
    }

    PlasmaComponents3.SpinBox {
        id: maxRowsSpin
        from: 3
        to: 20
        value: 8
    }

    PlasmaComponents3.Label {
        text: "Trigger icon name"
    }

    PlasmaComponents3.TextField {
        id: iconField
        placeholderText: "view-list-tree"
    }
}
