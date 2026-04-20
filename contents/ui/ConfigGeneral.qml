import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_hoverCloseDelayMs: closeDelaySpinBox.value
    property alias cfg_nodeStepPx: nodeStepSpinBox.value
    property alias cfg_filterCurrentDesktopOnly: filterDesktopCheck.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: closeDelaySpinBox
            Kirigami.FormData.label: i18n("Hover close delay (ms):")
            from: 100
            to: 2000
            stepSize: 50
        }

        QQC2.SpinBox {
            id: nodeStepSpinBox
            Kirigami.FormData.label: i18n("Node spacing (px):")
            from: 60
            to: 200
            stepSize: 4
        }

        QQC2.CheckBox {
            id: filterDesktopCheck
            Kirigami.FormData.label: i18n("Filter by virtual desktop:")
            text: i18n("Show only current desktop's windows")
        }
    }
}
