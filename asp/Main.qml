import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 960
    height: 640
    minimumWidth: 640
    minimumHeight: 500
    visible: true
    color: "#fafafa"
    title: qsTr("Admission Speciality Predictor")

    // Экземпляры C++ моделей абитуриентов
    CollegeApplicant {
        id: collegeApplicant
        onErrorOccurred: (msg) => { root.validationError = msg }
    }

    UniversityApplicant {
        id: universityApplicant
        onErrorOccurred: (msg) => { root.validationError = msg }
    }

    // Состояние UI
    property bool isUniversity: false
    property string savedFullName: ""
    property bool profileSavedNotice: false
    property string validationError: ""
    property int lastCalculatedScore: 0
    property bool hasSearched: false

    // Выбранные города (ВУЗ) и регионы (ССУЗ)
    property var selectedUniversityCities: []
    property var selectedCollegeRegions: []

    // Модель результатов подбора (вкладка «Главная»)
    ListModel {
        id: recommendationsModel
    }

    // Модель избранных специальностей (вкладка «Профиль»)
    ListModel {
        id: favoritesModel
    }

    // Инициалы для аватара в профиле
    function getInitials(name) {
        var parts = name.trim().split(/\s+/).filter(function(p) { return p.length > 0 })
        if (parts.length === 0)
            return "?"
        if (parts.length === 1)
            return parts[0].charAt(0).toUpperCase()
        return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase()
    }

    // Переключение флага города (для университета)
    function toggleUniversityCity(city) {
        var copy = root.selectedUniversityCities.slice()
        var idx = copy.indexOf(city)
        if (idx >= 0) {
            copy.splice(idx, 1)
        } else {
            copy.push(city)
        }
        root.selectedUniversityCities = copy
    }

    // Переключение флага региона (для колледжа)
    function toggleCollegeRegion(region) {
        var copy = root.selectedCollegeRegions.slice()
        var idx = copy.indexOf(region)
        if (idx >= 0) {
            copy.splice(idx, 1)
        } else {
            copy.push(region)
        }
        root.selectedCollegeRegions = copy
    }

    // Проверка, есть ли специальность в избранном
    function isFavorite(institutionName, specialty) {
        for (var i = 0; i < favoritesModel.count; ++i) {
            var f = favoritesModel.get(i)
            if (f.institutionName === institutionName && f.specialty === specialty)
                return true
        }
        return false
    }

    // Добавление / удаление из избранного
    function toggleFavorite(institutionName, specialty, city, passingScore, additionalInfo) {
        for (var i = 0; i < favoritesModel.count; ++i) {
            var f = favoritesModel.get(i)
            if (f.institutionName === institutionName && f.specialty === specialty) {
                favoritesModel.remove(i)
                return
            }
        }
        favoritesModel.append({
            institutionName: institutionName,
            specialty: specialty,
            city: city,
            passingScore: passingScore,
            additionalInfo: additionalInfo
        })
    }

    // Сохранение ФИО в профиле
    function saveProfileName() {
        var trimmed = fullNameField.text.trim()
        root.savedFullName = trimmed
        collegeApplicant.fullName = trimmed
        universityApplicant.fullName = trimmed
        root.profileSavedNotice = trimmed.length > 0
    }

    // Фильтрация списка предметов ЦТ, чтобы исключить предмет, уже выбранный в ЦЭ 2
    function updateCtSubjectsModel() {
        if (!ceProfileSubjectCombo || !ctSubjectCombo)
            return

        var selectedCe = ceProfileSubjectCombo.currentText
        var prevCt = ctSubjectCombo.currentText
        var allSubjects = AppConstants.profileExamSubjects
        var filtered = []

        for (var i = 0; i < allSubjects.length; ++i) {
            if (allSubjects[i] !== selectedCe) {
                filtered.push(allSubjects[i])
            }
        }

        ctSubjectCombo.model = filtered
        var restoredIndex = filtered.indexOf(prevCt)
        ctSubjectCombo.currentIndex = restoredIndex >= 0 ? restoredIndex : 0
    }

    // Проверка, относится ли предложение к бюджетной форме обучения
    function isBudgetOffer(item) {
        var info = (item.additionalInfo !== undefined ? String(item.additionalInfo) : "").toLowerCase()
        return info.indexOf("бюджет") !== -1 || info.indexOf("budget") !== -1
    }

    // Подписка на сигналы асинхронного сервиса рекомендаций
    Connections {
        target: recommendationService

        function onResultsReady(results) {
            root.validationError = ""
            root.hasSearched = true
            recommendationsModel.clear()

            var items = []
            for (var i = 0; i < results.length; ++i) {
                items.push(results[i])
            }

            // Для университета приоритет отдаётся выбранной форме обучения (бюджет / платно)
            if (root.isUniversity) {
                var preferBudget = uniStudyFormCombo.currentText.toLowerCase().indexOf("бюджет") !== -1
                items.sort(function(a, b) {
                    var aMatch = (root.isBudgetOffer(a) === preferBudget) ? 0 : 1
                    var bMatch = (root.isBudgetOffer(b) === preferBudget) ? 0 : 1
                    return aMatch - bMatch
                })
            }

            for (var j = 0; j < items.length; ++j) {
                var item = items[j]
                recommendationsModel.append({
                    institutionName: item.institutionName !== undefined ? item.institutionName : "",
                    specialty: item.specialty !== undefined ? item.specialty : "",
                    city: item.city !== undefined ? item.city : "",
                    passingScore: item.passingScore !== undefined ? item.passingScore : 0,
                    additionalInfo: item.additionalInfo !== undefined ? item.additionalInfo : ""
                })
            }
        }

        function onErrorOccurred(errorMessage) {
            root.validationError = errorMessage
        }
    }

    // Парсинг дробного числа (поддержка точки и запятой)
    function parseGpa(text) {
        var normalized = text.trim().replace(",", ".")
        if (normalized.length === 0)
            return NaN
        return Number(normalized)
    }

    // Парсинг целого балла экзамена (0–100)
    function parseExamScore(text) {
        var trimmed = text.trim()
        if (!/^\d+$/.test(trimmed))
            return NaN
        return parseInt(trimmed, 10)
    }

    // Валидация и отправка запроса с вкладки «Главная»
    function submitSearch() {
        root.validationError = ""

        var fullName = root.savedFullName.trim()
        if (fullName.length === 0) {
            fullName = fullNameField.text.trim()
            if (fullName.length > 0) {
                root.savedFullName = fullName
            }
        }
        if (fullName.length === 0) {
            root.validationError = qsTr("Сначала укажите ФИО во вкладке «Профиль».")
            return
        }

        var gpaVal = parseGpa(gpaField.text)
        if (isNaN(gpaVal) || gpaVal < 0.0 || gpaVal > 10.0) {
            root.validationError = qsTr("Средний балл аттестата должен быть числом от 0.0 до 10.0.")
            return
        }

        var payload = {}

        if (!root.isUniversity) {
            if (!directionCombo.currentText || !profileCombo.currentText || !studyFormCombo.currentText) {
                root.validationError = qsTr("Выберите направление, профиль и форму обучения.")
                return
            }

            collegeApplicant.fullName = fullName
            collegeApplicant.gpa = gpaVal
            collegeApplicant.direction = directionCombo.currentText
            collegeApplicant.profile = profileCombo.currentText
            collegeApplicant.studyForm = studyFormCombo.currentText
            collegeApplicant.regions = root.selectedCollegeRegions

            payload = collegeApplicant.toJson()
            root.lastCalculatedScore = payload.totalScore !== undefined ? payload.totalScore : 0
        } else {
            if (!uniStudyFormCombo.currentText) {
                root.validationError = qsTr("Выберите форму обучения.")
                return
            }

            var s1 = ceLangSubjectCombo.currentText
            var s2 = ceProfileSubjectCombo.currentText
            var s3 = ctSubjectCombo.currentText

            if (s1 === s2 || s1 === s3 || s2 === s3) {
                root.validationError = qsTr("Предметы ЦЭ и ЦТ не должны повторяться.")
                return
            }

            var score1 = parseExamScore(ceLangScoreField.text)
            var score2 = parseExamScore(ceProfileScoreField.text)
            var score3 = parseExamScore(ctScoreField.text)

            if (isNaN(score1) || score1 < 0 || score1 > 100 ||
                isNaN(score2) || score2 < 0 || score2 > 100 ||
                isNaN(score3) || score3 < 0 || score3 > 100) {
                root.validationError = qsTr("Заполните все 3 балла экзаменов (целые числа от 0 до 100).")
                return
            }

            universityApplicant.fullName = fullName
            universityApplicant.gpa = gpaVal
            universityApplicant.studyForm = uniStudyFormCombo.currentText
            universityApplicant.cities = root.selectedUniversityCities

            var examsPayload = [
                { subject: s1, score: score1, examType: "CE" },
                { subject: s2, score: score2, examType: "CE" },
                { subject: s3, score: score3, examType: "CT" }
            ]

            if (!universityApplicant.setExams(examsPayload)) {
                return
            }

            payload = universityApplicant.toJson()
            root.lastCalculatedScore = payload.totalScore !== undefined ? payload.totalScore : 0
        }

        recommendationService.submitRequest(payload)
    }

    // Переиспользуемый стилизованный TextField с контрастным тёмным текстом
    component StyledTextField: TextField {
        id: field
        font.family: "Arial"
        font.pointSize: 12
        color: "#222222"
        placeholderTextColor: "#7f8c8d"
        selectionColor: "#4e6a85"
        selectedTextColor: "#ffffff"
        leftPadding: 10
        rightPadding: 10
        background: Rectangle {
            color: "#ffffff"
            border.color: field.activeFocus ? "#34495e" : "#cccccc"
            border.width: 1
            radius: 6
        }
    }

    // Переиспользуемый стилизованный ComboBox с контрастным тёмным текстом
    component StyledComboBox: ComboBox {
        id: control
        font.family: "Arial"
        font.pointSize: 12

        contentItem: Text {
            leftPadding: 10
            rightPadding: control.indicator.width + control.spacing
            text: control.displayText
            font: control.font
            color: "#222222"
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            color: "#ffffff"
            border.color: control.activeFocus || control.pressed ? "#34495e" : "#cccccc"
            border.width: 1
            radius: 6
        }

        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: control.width
            contentItem: Text {
                text: modelData
                color: "#222222"
                font: control.font
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: highlighted ? "#e8ecef" : "#ffffff"
            }
            highlighted: control.highlightedIndex === index
        }

        popup: Popup {
            y: control.height - 1
            width: control.width
            implicitHeight: contentItem.implicitHeight
            padding: 1

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }

            background: Rectangle {
                color: "#ffffff"
                border.color: "#cccccc"
                radius: 6
            }
        }
    }

    // Компактный чекбокс-флаг для множественного выбора городов / регионов
    component LocationFlag: Rectangle {
        id: flagBox
        property string label: ""
        property bool checked: false
        signal toggled()

        implicitWidth: flagRow.implicitWidth + 18
        implicitHeight: flagRow.implicitHeight + 12
        radius: 6
        color: checked ? "#e8ecef" : (flagMouse.containsMouse ? "#f4f6f8" : "#ffffff")
        border.color: checked ? "#34495e" : "#cccccc"
        border.width: 1

        Row {
            id: flagRow
            anchors.centerIn: parent
            spacing: 7

            Rectangle {
                width: 15
                height: 15
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: flagBox.checked ? "#34495e" : "#ffffff"
                border.color: flagBox.checked ? "#34495e" : "#95a5a6"
                border.width: 1.2

                Text {
                    anchors.centerIn: parent
                    visible: flagBox.checked
                    text: "✓"
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: 10
                }
            }

            Text {
                text: flagBox.label
                color: "#222222"
                font.family: "Arial"
                font.pointSize: 10
                font.bold: flagBox.checked
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: flagMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: flagBox.toggled()
        }
    }

    // Компактная стилизованная кнопка-действие («Выбрать все» / «Сбросить»)
    component ActionChipButton: Button {
        id: chipBtn
        property bool destructive: false

        flat: true
        hoverEnabled: true
        leftPadding: 10
        rightPadding: 10
        topPadding: 5
        bottomPadding: 5

        HoverHandler {
            cursorShape: chipBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        background: Rectangle {
            radius: 5
            border.width: 1
            color: {
                if (!chipBtn.enabled)
                    return "#f2f4f6"
                if (chipBtn.destructive) {
                    if (chipBtn.down) return "#f9d6d2"
                    if (chipBtn.hovered) return "#fdedec"
                    return "#ffffff"
                } else {
                    if (chipBtn.down) return "#cedbe6"
                    if (chipBtn.hovered) return "#dce6ee"
                    return "#eef2f6"
                }
            }
            border.color: {
                if (!chipBtn.enabled)
                    return "#e0e4e8"
                if (chipBtn.destructive) {
                    return (chipBtn.hovered || chipBtn.down) ? "#e6b0aa" : "#d5d8dc"
                } else {
                    return (chipBtn.hovered || chipBtn.down) ? "#4e6a85" : "#c5d3df"
                }
            }

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        contentItem: Text {
            text: chipBtn.text
            font.family: "Arial"
            font.pointSize: 10
            font.bold: !chipBtn.destructive
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: {
                if (!chipBtn.enabled)
                    return "#a0aab4"
                if (chipBtn.destructive)
                    return (chipBtn.hovered || chipBtn.down) ? "#c0392b" : "#5d6d7e"
                return "#34495e"
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // ЛЕВАЯ ЧАСТЬ: Боковая панель навигации
        // ==========================================
        Rectangle {
            id: sidePanel
            property bool isExpanded: true

            Layout.fillHeight: true
            Layout.preferredWidth: isExpanded ? 200 : 50

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            color: "#34495e"

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 12
                spacing: 15
                width: parent.width - 24

                RowLayout {
                    width: parent.width
                    spacing: 10

                    Button {
                        id: toggleButton
                        text: sidePanel.isExpanded ? "<" : ">"
                        flat: true
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        onClicked: sidePanel.isExpanded = !sidePanel.isExpanded

                        contentItem: Text {
                            text: toggleButton.text
                            color: "#ffffff"
                            font.bold: true
                            font.family: "Arial"
                            font.pointSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: qsTr("МЕНЮ")
                        color: "#ffffff"
                        font.bold: true
                        font.family: "Arial"
                        font.pointSize: 16
                        Layout.fillWidth: true
                        visible: sidePanel.isExpanded
                    }
                }

                // Кнопка 1: Профиль
                Button {
                    id: btnProfile
                    width: parent.width
                    flat: true
                    visible: sidePanel.isExpanded
                    onClicked: stackLayout.currentIndex = 0

                    background: Rectangle {
                        color: stackLayout.currentIndex === 0 ? "#4e6a85" : "transparent"
                        radius: 4
                    }

                    contentItem: Text {
                        text: qsTr("Профиль")
                        color: "#ffffff"
                        font.bold: stackLayout.currentIndex === 0
                        font.family: "Arial"
                        font.pointSize: 16
                        leftPadding: 8
                    }
                }

                // Кнопка 2: Главная
                Button {
                    id: btnHome
                    width: parent.width
                    flat: true
                    visible: sidePanel.isExpanded
                    onClicked: stackLayout.currentIndex = 1

                    background: Rectangle {
                        color: stackLayout.currentIndex === 1 ? "#4e6a85" : "transparent"
                        radius: 4
                    }

                    contentItem: Text {
                        text: qsTr("Главная")
                        color: "#ffffff"
                        font.bold: stackLayout.currentIndex === 1
                        font.family: "Arial"
                        font.pointSize: 16
                        leftPadding: 8
                    }
                }

                // Кнопка 3: Источники
                Button {
                    id: btnSources
                    width: parent.width
                    flat: true
                    visible: sidePanel.isExpanded
                    onClicked: stackLayout.currentIndex = 2

                    background: Rectangle {
                        color: stackLayout.currentIndex === 2 ? "#4e6a85" : "transparent"
                        radius: 4
                    }

                    contentItem: Text {
                        text: qsTr("Источники")
                        color: "#ffffff"
                        font.bold: stackLayout.currentIndex === 2
                        font.family: "Arial"
                        font.pointSize: 16
                        leftPadding: 8
                    }
                }

                // Кнопка 4: Информация
                Button {
                    id: btnInfo
                    width: parent.width
                    flat: true
                    visible: sidePanel.isExpanded
                    onClicked: stackLayout.currentIndex = 3

                    background: Rectangle {
                        color: stackLayout.currentIndex === 3 ? "#4e6a85" : "transparent"
                        radius: 4
                    }

                    contentItem: Text {
                        text: qsTr("Информация")
                        color: "#ffffff"
                        font.bold: stackLayout.currentIndex === 3
                        font.family: "Arial"
                        font.pointSize: 16
                        leftPadding: 8
                    }
                }
            }
        }

        // ==========================================
        // ПРАВАЯ ЧАСТЬ: Контент вкладок
        // ==========================================
        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // 1. ВКЛАДКА: ПРОФИЛЬ (регистрация имени + сводка + избранное)
            ScrollView {
                id: profileScroll
                clip: true
                contentWidth: availableWidth
                background: Rectangle { color: "#fafafa" }

                readonly property bool isWide: availableWidth >= 820

                Rectangle {
                    width: profileScroll.availableWidth
                    implicitHeight: Math.max(profileScroll.availableHeight, profileGrid.implicitHeight + 48)
                    color: "#fafafa"

                    GridLayout {
                        id: profileGrid
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 24
                        columns: profileScroll.isWide ? 2 : 1
                        columnSpacing: 24
                        rowSpacing: 24

                        // --- ЛЕВАЯ КАРТОЧКА: Регистрация имени и сводка ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: profileScroll.isWide ? 460 : 400
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: nameCardCol.implicitHeight + 40
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            radius: 8

                            ColumnLayout {
                                id: nameCardCol
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 20
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 14

                                    Rectangle {
                                        width: 54
                                        height: 54
                                        radius: 27
                                        color: "#34495e"

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.getInitials(root.savedFullName.length > 0
                                                                   ? root.savedFullName
                                                                   : fullNameField.text)
                                            color: "#ffffff"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: root.savedFullName.length > 0
                                                  ? root.savedFullName
                                                  : qsTr("Мой профиль")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 18
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.savedFullName.length > 0
                                                  ? qsTr("Профиль абитуриента активен")
                                                  : qsTr("Укажите ФИО для персонализации подбора")
                                            color: "dimgray"
                                            font.family: "Arial"
                                            font.pointSize: 11
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                StyledTextField {
                                    id: fullNameField
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("ФИО (например, Иванов И.И.)")
                                    onTextEdited: root.profileSavedNotice = false
                                    onAccepted: root.saveProfileName()
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Button {
                                        id: saveNameBtn
                                        text: qsTr("Сохранить профиль")
                                        highlighted: true
                                        onClicked: root.saveProfileName()

                                        background: Rectangle {
                                            color: saveNameBtn.down ? "#2c3e50"
                                                 : saveNameBtn.hovered ? "#4e6a85"
                                                 : "#34495e"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: saveNameBtn.text
                                            color: "#ffffff"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 14
                                            rightPadding: 14
                                            topPadding: 8
                                            bottomPadding: 8
                                        }
                                    }

                                    Button {
                                        id: goToSearchBtn
                                        text: qsTr("К подбору →")
                                        flat: true
                                        onClicked: stackLayout.currentIndex = 1

                                        background: Rectangle {
                                            color: goToSearchBtn.hovered ? "#dce3e8" : "#e8ecef"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: goToSearchBtn.text
                                            color: "#34495e"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 12
                                            rightPadding: 12
                                            topPadding: 8
                                            bottomPadding: 8
                                        }
                                    }
                                }

                                Text {
                                    visible: root.profileSavedNotice
                                    text: qsTr("Имя сохранено и будет использоваться при подборе специальностей.")
                                    color: "#2e7d32"
                                    font.family: "Arial"
                                    font.pointSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: statsRow.implicitHeight + 20
                                    color: "#f4f6f8"
                                    radius: 6

                                    RowLayout {
                                        id: statsRow
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: root.lastCalculatedScore > 0
                                                      ? String(root.lastCalculatedScore)
                                                      : "—"
                                                color: "#34495e"
                                                font.bold: true
                                                font.family: "Arial"
                                                font.pointSize: 16
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            Text {
                                                text: qsTr("Ваш балл")
                                                color: "dimgray"
                                                font.family: "Arial"
                                                font.pointSize: 10
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }

                                        Rectangle { width: 1; Layout.fillHeight: true; color: "#dce3e8" }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: String(favoritesModel.count)
                                                color: "#34495e"
                                                font.bold: true
                                                font.family: "Arial"
                                                font.pointSize: 16
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            Text {
                                                text: qsTr("В избранном")
                                                color: "dimgray"
                                                font.family: "Arial"
                                                font.pointSize: 10
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }

                                        Rectangle { width: 1; Layout.fillHeight: true; color: "#dce3e8" }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: root.isUniversity ? qsTr("ВУЗ") : qsTr("ССУЗ")
                                                color: "#34495e"
                                                font.bold: true
                                                font.family: "Arial"
                                                font.pointSize: 16
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            Text {
                                                text: qsTr("Режим")
                                                color: "dimgray"
                                                font.family: "Arial"
                                                font.pointSize: 10
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- ПРАВАЯ КАРТОЧКА: Избранные специальности ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: profileScroll.isWide ? 440 : 400
                            Layout.fillHeight: profileScroll.isWide
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: Math.max(favoritesCardCol.implicitHeight + 40,
                                                     profileScroll.isWide ? 280 : 180)
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            radius: 8

                            ColumnLayout {
                                id: favoritesCardCol
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 20
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: qsTr("Избранное")
                                        color: "#222222"
                                        font.bold: true
                                        font.family: "Arial"
                                        font.pointSize: 18
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        visible: favoritesModel.count > 0
                                        color: "#4e6a85"
                                        radius: 10
                                        implicitWidth: favCountTxt.implicitWidth + 14
                                        implicitHeight: favCountTxt.implicitHeight + 4

                                        Text {
                                            id: favCountTxt
                                            anchors.centerIn: parent
                                            text: String(favoritesModel.count)
                                            color: "#ffffff"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 10
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 16
                                    spacing: 8
                                    visible: favoritesModel.count === 0

                                    Text {
                                        text: qsTr("Здесь будет список предпочтительных Вам специальностей")
                                        font.family: "Arial"
                                        font.pointSize: 12
                                        color: "dimgray"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        text: qsTr("Подберите варианты во вкладке «Главная» и нажмите «В избранное» на понравившихся карточках.")
                                        font.family: "Arial"
                                        font.pointSize: 11
                                        color: "#7f8c8d"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Repeater {
                                    model: favoritesModel

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: favItemCol.implicitHeight + 20
                                        color: "#fafafa"
                                        border.color: "#dcdcdc"
                                        border.width: 1
                                        radius: 6

                                        ColumnLayout {
                                            id: favItemCol
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 10
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    text: model.institutionName
                                                    color: "#34495e"
                                                    font.bold: true
                                                    font.family: "Arial"
                                                    font.pointSize: 13
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Button {
                                                    text: "✕"
                                                    flat: true
                                                    implicitWidth: 26
                                                    implicitHeight: 26
                                                    onClicked: favoritesModel.remove(index)

                                                    contentItem: Text {
                                                        text: "✕"
                                                        color: "#7f8c8d"
                                                        font.bold: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }
                                            }

                                            Text {
                                                text: model.specialty
                                                color: "#222222"
                                                font.family: "Arial"
                                                font.pointSize: 11
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12

                                                Text {
                                                    text: qsTr("Балл: %1").arg(model.passingScore)
                                                    color: "#4e6a85"
                                                    font.bold: true
                                                    font.family: "Arial"
                                                    font.pointSize: 10
                                                }

                                                Text {
                                                    text: model.city
                                                    color: "dimgray"
                                                    font.family: "Arial"
                                                    font.pointSize: 10
                                                }

                                                Text {
                                                    text: model.additionalInfo
                                                    color: "dimgray"
                                                    font.family: "Arial"
                                                    font.pointSize: 10
                                                    visible: model.additionalInfo.length > 0
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. ВКЛАДКА: ГЛАВНАЯ (форма подбора + выбор городов/регионов + результаты)
            ScrollView {
                id: homeScroll
                clip: true
                contentWidth: availableWidth
                background: Rectangle { color: "#fafafa" }

                readonly property bool isWide: availableWidth >= 880

                Rectangle {
                    width: homeScroll.availableWidth
                    implicitHeight: Math.max(homeScroll.availableHeight, homeGrid.implicitHeight + 48)
                    color: "#fafafa"

                    GridLayout {
                        id: homeGrid
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 24
                        columns: homeScroll.isWide ? 2 : 1
                        columnSpacing: 24
                        rowSpacing: 24

                        // --- КАРТОЧКА ПОИСКА И ПАРАМЕТРОВ ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: homeScroll.isWide ? 450 : 400
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: searchCardCol.implicitHeight + 40
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            radius: 8

                            ColumnLayout {
                                id: searchCardCol
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 20
                                spacing: 12

                                Text {
                                    text: qsTr("Подбор специальности")
                                    color: "#222222"
                                    font.bold: true
                                    font.family: "Arial"
                                    font.pointSize: 18
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.savedFullName.length > 0
                                          ? qsTr("Абитуриент: %1").arg(root.savedFullName)
                                          : qsTr("Заполните параметры поступления (ФИО указывается в «Профиле»).")
                                    color: "dimgray"
                                    font.family: "Arial"
                                    font.pointSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                // Переключатель: Колледж / Университет
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Button {
                                        Layout.fillWidth: true
                                        flat: true
                                        onClicked: {
                                            root.isUniversity = false
                                            root.validationError = ""
                                        }
                                        background: Rectangle {
                                            color: !root.isUniversity ? "#34495e" : "#e8ecef"
                                            radius: 6
                                        }
                                        contentItem: Text {
                                            text: qsTr("Колледж (ССУЗ)")
                                            color: !root.isUniversity ? "#ffffff" : "#34495e"
                                            font.bold: !root.isUniversity
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        flat: true
                                        onClicked: {
                                            root.isUniversity = true
                                            root.validationError = ""
                                        }
                                        background: Rectangle {
                                            color: root.isUniversity ? "#34495e" : "#e8ecef"
                                            radius: 6
                                        }
                                        contentItem: Text {
                                            text: qsTr("Университет (ВУЗ)")
                                            color: root.isUniversity ? "#ffffff" : "#34495e"
                                            font.bold: root.isUniversity
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // Средний балл аттестата (0.0–10.0)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    StyledTextField {
                                        id: gpaField
                                        Layout.preferredWidth: 185
                                        placeholderText: qsTr("Средний балл (0–10)")
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                                        validator: DoubleValidator {
                                            bottom: 0.0
                                            top: 10.0
                                            decimals: 2
                                            notation: DoubleValidator.StandardNotation
                                        }
                                    }

                                    Text {
                                        text: qsTr("Шкала: 0.0–10.0")
                                        font.family: "Arial"
                                        font.pointSize: 11
                                        color: "dimgray"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // --- БЛОК КОЛЛЕДЖА: сфера интересов + регионы ---
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: !root.isUniversity

                                    Text {
                                        text: qsTr("Сфера интересов")
                                        color: "#222222"
                                        font.bold: true
                                        font.family: "Arial"
                                        font.pointSize: 13
                                        Layout.topMargin: 4
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("Направление:")
                                            color: "#222222"
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 120
                                        }
                                        StyledComboBox {
                                            id: directionCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.directions
                                            onCurrentTextChanged: {
                                                profileCombo.model = AppConstants.profilesForDirection(currentText)
                                                profileCombo.currentIndex = 0
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("Профиль:")
                                            color: "#222222"
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 120
                                        }
                                        StyledComboBox {
                                            id: profileCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.profilesForDirection(directionCombo.currentText)
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("Форма обучения:")
                                            color: "#222222"
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 120
                                        }
                                        StyledComboBox {
                                            id: studyFormCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.studyForms
                                        }
                                    }

                                    // Флаги выбора регионов для колледжа (Минск + области)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 6
                                        spacing: 6

                                        Text {
                                            text: qsTr("Регионы поступления")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 13
                                            Layout.fillWidth: true
                                        }

                                        ActionChipButton {
                                            text: qsTr("Выбрать все")
                                            enabled: root.selectedCollegeRegions.length < AppConstants.collegeRegions.length
                                            onClicked: root.selectedCollegeRegions = AppConstants.collegeRegions.slice()
                                        }

                                        ActionChipButton {
                                            text: qsTr("Сбросить")
                                            destructive: true
                                            visible: root.selectedCollegeRegions.length > 0
                                            onClicked: root.selectedCollegeRegions = []
                                        }
                                    }

                                    Text {
                                        text: root.selectedCollegeRegions.length === 0
                                              ? qsTr("Не выбрано — поиск по всей Беларуси")
                                              : qsTr("Выбрано регионов: %1").arg(root.selectedCollegeRegions.length)
                                        color: "dimgray"
                                        font.family: "Arial"
                                        font.pointSize: 10
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: AppConstants.collegeRegions

                                            delegate: LocationFlag {
                                                required property string modelData
                                                label: modelData
                                                checked: root.selectedCollegeRegions.indexOf(modelData) !== -1
                                                onToggled: root.toggleCollegeRegion(modelData)
                                            }
                                        }
                                    }
                                }

                                // --- БЛОК УНИВЕРСИТЕТА: 2 ЦЭ + 1 ЦТ + форма обучения + города ---
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: root.isUniversity

                                    Text {
                                        text: qsTr("Результаты экзаменов (2 ЦЭ + 1 ЦТ)")
                                        color: "#222222"
                                        font.bold: true
                                        font.family: "Arial"
                                        font.pointSize: 13
                                        Layout.topMargin: 4
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    // ЦЭ 1: только Русский / Белорусский
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("ЦЭ 1 (язык):")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 94
                                        }
                                        StyledComboBox {
                                            id: ceLangSubjectCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.languageExamSubjects
                                            currentIndex: 0
                                        }
                                        StyledTextField {
                                            id: ceLangScoreField
                                            Layout.preferredWidth: 88
                                            placeholderText: qsTr("0–100")
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 0; top: 100 }
                                        }
                                    }

                                    // ЦЭ 2: профильные предметы
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("ЦЭ 2:")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 94
                                        }
                                        StyledComboBox {
                                            id: ceProfileSubjectCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.profileExamSubjects
                                            currentIndex: 0
                                            onCurrentTextChanged: root.updateCtSubjectsModel()
                                        }
                                        StyledTextField {
                                            id: ceProfileScoreField
                                            Layout.preferredWidth: 88
                                            placeholderText: qsTr("0–100")
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 0; top: 100 }
                                        }
                                    }

                                    // ЦТ: профильные предметы (без предмета, выбранного в ЦЭ 2)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("ЦТ:")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 94
                                        }
                                        StyledComboBox {
                                            id: ctSubjectCombo
                                            Layout.fillWidth: true
                                            Component.onCompleted: root.updateCtSubjectsModel()
                                        }
                                        StyledTextField {
                                            id: ctScoreField
                                            Layout.preferredWidth: 88
                                            placeholderText: qsTr("0–100")
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 0; top: 100 }
                                        }
                                    }

                                    // Форма обучения для университета (Бюджет / Платно)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 2
                                        spacing: 10

                                        Text {
                                            text: qsTr("Форма обучения:")
                                            color: "#222222"
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 120
                                        }

                                        StyledComboBox {
                                            id: uniStudyFormCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.studyForms
                                            currentIndex: 0
                                        }
                                    }

                                    // Флаги выбора городов для университета
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 6
                                        spacing: 6

                                        Text {
                                            text: qsTr("Города поступления")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 13
                                            Layout.fillWidth: true
                                        }

                                        ActionChipButton {
                                            text: qsTr("Выбрать все")
                                            enabled: root.selectedUniversityCities.length < AppConstants.universityCities.length
                                            onClicked: root.selectedUniversityCities = AppConstants.universityCities.slice()
                                        }

                                        ActionChipButton {
                                            text: qsTr("Сбросить")
                                            destructive: true
                                            visible: root.selectedUniversityCities.length > 0
                                            onClicked: root.selectedUniversityCities = []
                                        }
                                    }

                                    Text {
                                        text: root.selectedUniversityCities.length === 0
                                              ? qsTr("Не выбрано — поиск по всем городам")
                                              : qsTr("Выбрано городов: %1").arg(root.selectedUniversityCities.length)
                                        color: "dimgray"
                                        font.family: "Arial"
                                        font.pointSize: 10
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: AppConstants.universityCities

                                            delegate: LocationFlag {
                                                required property string modelData
                                                label: modelData
                                                checked: root.selectedUniversityCities.indexOf(modelData) !== -1
                                                onToggled: root.toggleUniversityCity(modelData)
                                            }
                                        }
                                    }
                                }

                                // Сообщение об ошибке валидации / сервиса
                                Text {
                                    Layout.fillWidth: true
                                    visible: root.validationError.length > 0
                                    text: root.validationError
                                    color: "#c0392b"
                                    font.family: "Arial"
                                    font.pointSize: 11
                                    wrapMode: Text.WordWrap
                                }

                                // Кнопка «Подобрать» и индикатор загрузки
                                RowLayout {
                                    Layout.topMargin: 4
                                    spacing: 12

                                    Button {
                                        id: submitBtn
                                        text: qsTr("Подобрать")
                                        highlighted: true
                                        enabled: !recommendationService.busy
                                        onClicked: root.submitSearch()

                                        background: Rectangle {
                                            color: !submitBtn.enabled ? "#95a5a6"
                                                 : submitBtn.down ? "#2c3e50"
                                                 : submitBtn.hovered ? "#4e6a85"
                                                 : "#34495e"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: submitBtn.text
                                            color: "#ffffff"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 18
                                            rightPadding: 18
                                            topPadding: 8
                                            bottomPadding: 8
                                        }
                                    }

                                    BusyIndicator {
                                        running: recommendationService.busy
                                        visible: recommendationService.busy
                                        implicitWidth: 28
                                        implicitHeight: 28
                                    }

                                    Text {
                                        visible: recommendationService.busy
                                        text: qsTr("Подбираем специальности...")
                                        font.family: "Arial"
                                        font.pointSize: 11
                                        color: "dimgray"
                                    }
                                }
                            }
                        }

                        // --- ОБЛАСТЬ РЕЗУЛЬТАТОВ ПОДБОРА ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: homeScroll.isWide ? 470 : 400
                            Layout.fillHeight: homeScroll.isWide
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: Math.max(resultsAreaCol.implicitHeight + 40,
                                                     homeScroll.isWide ? 420 : 200)
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            radius: 8

                            ColumnLayout {
                                id: resultsAreaCol
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 20
                                spacing: 12

                                Text {
                                    text: qsTr("Рекомендуемые специальности")
                                    color: "#222222"
                                    font.bold: true
                                    font.family: "Arial"
                                    font.pointSize: 18
                                    Layout.fillWidth: true
                                }

                                // Пустое состояние
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 20
                                    spacing: 8
                                    visible: recommendationsModel.count === 0 && !recommendationService.busy

                                    Text {
                                        text: root.hasSearched
                                              ? qsTr("Подходящих вариантов не найдено")
                                              : qsTr("Добро пожаловать в систему!")
                                        color: "#222222"
                                        font.bold: true
                                        font.family: "Arial"
                                        font.pointSize: 14
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        text: root.hasSearched
                                              ? qsTr("Попробуйте расширить список выбранных городов или регионов.")
                                              : qsTr("Здесь будет отображаться список рекомендуемых специальностей")
                                        font.family: "Arial"
                                        font.pointSize: 12
                                        color: "gray"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Индикатор загрузки
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 24
                                    spacing: 10
                                    visible: recommendationService.busy

                                    BusyIndicator {
                                        running: recommendationService.busy
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: qsTr("Загрузка рекомендаций...")
                                        font.family: "Arial"
                                        font.pointSize: 12
                                        color: "dimgray"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                // Карточки подобранных специальностей (EducationOffer)
                                Repeater {
                                    model: recommendationsModel

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: offerCardColumn.implicitHeight + 24
                                        color: "#fafafa"
                                        border.color: "#dcdcdc"
                                        border.width: 1
                                        radius: 6
                                        visible: !recommendationService.busy

                                        ColumnLayout {
                                            id: offerCardColumn
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 12
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    text: model.institutionName
                                                    font.bold: true
                                                    font.family: "Arial"
                                                    font.pointSize: 14
                                                    color: "#34495e"
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    color: "#4e6a85"
                                                    radius: 4
                                                    implicitWidth: scoreBadgeText.implicitWidth + 14
                                                    implicitHeight: scoreBadgeText.implicitHeight + 6

                                                    Text {
                                                        id: scoreBadgeText
                                                        anchors.centerIn: parent
                                                        text: qsTr("Проходной: %1").arg(model.passingScore)
                                                        color: "#ffffff"
                                                        font.bold: true
                                                        font.family: "Arial"
                                                        font.pointSize: 10
                                                    }
                                                }
                                            }

                                            Text {
                                                text: model.specialty
                                                font.family: "Arial"
                                                font.pointSize: 12
                                                color: "#222222"
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12

                                                Text {
                                                    text: qsTr("Город: %1").arg(model.city)
                                                    font.family: "Arial"
                                                    font.pointSize: 11
                                                    color: "dimgray"
                                                }

                                                Text {
                                                    text: qsTr("Условия: %1").arg(model.additionalInfo)
                                                    font.family: "Arial"
                                                    font.pointSize: 11
                                                    color: "dimgray"
                                                    visible: model.additionalInfo.length > 0
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Button {
                                                    id: favBtn
                                                    readonly property bool saved: favoritesModel.count >= 0
                                                                                  && root.isFavorite(model.institutionName, model.specialty)
                                                    text: saved ? qsTr("★ В избранном") : qsTr("☆ В избранное")
                                                    flat: true
                                                    onClicked: root.toggleFavorite(
                                                        model.institutionName,
                                                        model.specialty,
                                                        model.city,
                                                        model.passingScore,
                                                        model.additionalInfo)

                                                    background: Rectangle {
                                                        color: favBtn.saved ? "#34495e" : "#e8ecef"
                                                        radius: 4
                                                    }

                                                    contentItem: Text {
                                                        text: favBtn.text
                                                        color: favBtn.saved ? "#ffffff" : "#34495e"
                                                        font.bold: favBtn.saved
                                                        font.family: "Arial"
                                                        font.pointSize: 10
                                                        leftPadding: 8
                                                        rightPadding: 8
                                                        topPadding: 4
                                                        bottomPadding: 4
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. ВКЛАДКА: ИСТОЧНИКИ
            ScrollView {
                id: sourcesScroll
                clip: true
                contentWidth: availableWidth
                background: Rectangle { color: "#fafafa" }

                Column {
                    width: sourcesScroll.availableWidth
                    spacing: 12
                    padding: 25
                    Text {
                        text: qsTr("Полезные ресурсы и проходные баллы")
                        color: "#222222"
                        font.bold: true
                        font.family: "Arial"
                        font.pointSize: 16
                        bottomPadding: 10
                        width: parent.width - 50
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        text: qsTr("• <b>KudaPostupat.by</b> — Электронный справочник абитуриента")
                        color: "#222222"
                        font.family: "Arial"
                        font.pointSize: 12
                        textFormat: Text.RichText
                        width: parent.width - 50
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        text: qsTr("• <b>Abiturient.by</b> — Официальный сайт мониторинга вступительной кампании")
                        color: "#222222"
                        font.family: "Arial"
                        font.pointSize: 12
                        textFormat: Text.RichText
                        width: parent.width - 50
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // 4. ВКЛАДКА: ИНФОРМАЦИЯ
            Rectangle {
                color: "#f4f4f4"
                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 520)
                    spacing: 10
                    Text {
                        text: qsTr("Модель подбора специальности для поступления\n")
                        color: "#222222"
                        font.bold: true
                        font.family: "Arial"
                        font.pointSize: 16
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: qsTr("Разработчики:\nПашкевич Н.В.\nТретьяк М.М.\nШумский М.В.")
                        color: "#222222"
                        font.family: "Arial"
                        font.pointSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}