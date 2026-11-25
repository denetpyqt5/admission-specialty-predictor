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
    property string validationError: ""

    // Модель для отображения результатов подбора на вкладке «Главная»
    ListModel {
        id: recommendationsModel
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
            recommendationsModel.clear()

            var items = []
            for (var i = 0; i < results.length; ++i) {
                items.push(results[i])
            }

            // Для университета приоритет отдаётся бюджетным специальностям
            if (root.isUniversity) {
                items.sort(function(a, b) {
                    var aBudget = root.isBudgetOffer(a) ? 0 : 1
                    var bBudget = root.isBudgetOffer(b) ? 0 : 1
                    return aBudget - bBudget
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
            stackLayout.currentIndex = 1
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

    // Валидация и отправка запроса
    function submitProfile() {
        root.validationError = ""

        var fullName = fullNameField.text.trim()
        if (fullName.length === 0) {
            root.validationError = qsTr("Введите ФИО абитуриента.")
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

            payload = collegeApplicant.toJson()
        } else {
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

            var examsPayload = [
                { subject: s1, score: score1, examType: "CE" },
                { subject: s2, score: score2, examType: "CE" },
                { subject: s3, score: score3, examType: "CT" }
            ]

            if (!universityApplicant.setExams(examsPayload)) {
                return
            }

            payload = universityApplicant.toJson()
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // ЛЕВАЯ ЧАСТЬ: Светло-синяя боковая панель
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

                // Верхний блок: кнопка переключения и заголовок
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

            // 1. ВКЛАДКА: ПРОФИЛЬ (адаптивная: 2 колонки на широком экране, 1 — на узком)
            ScrollView {
                id: profileScroll
                clip: true
                contentWidth: availableWidth
                background: Rectangle { color: "#fafafa" }

                readonly property bool isWide: availableWidth >= 820

                Rectangle {
                    width: profileScroll.availableWidth
                    implicitHeight: Math.max(profileScroll.availableHeight, profileGrid.implicitHeight + 50)
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

                        // --- КАРТОЧКА 1: МОЙ ПРОФИЛЬ ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: profileScroll.isWide ? 560 : 400
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: profileCardColumn.implicitHeight + 40
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            radius: 8

                            ColumnLayout {
                                id: profileCardColumn
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 20
                                spacing: 12

                                Text {
                                    text: qsTr("Мой профиль")
                                    color: "#222222"
                                    font.bold: true
                                    font.family: "Arial"
                                    font.pointSize: 20
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: qsTr("Создайте свой профиль и выбирайте понравившиеся специальности!")
                                    font.family: "Arial"
                                    font.pointSize: 12
                                    color: "dimgray"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    Layout.bottomMargin: 6
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

                                // ФИО
                                StyledTextField {
                                    id: fullNameField
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("ФИО (например, Иванов И.И.)")
                                }

                                // Средний балл аттестата (0.0–10.0)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    StyledTextField {
                                        id: gpaField
                                        Layout.preferredWidth: 190
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
                                        text: qsTr("Шкала: от 0.0 до 10.0")
                                        font.family: "Arial"
                                        font.pointSize: 11
                                        color: "dimgray"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // --- БЛОК КОЛЛЕДЖА: сфера интересов ---
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
                                        Layout.topMargin: 6
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("Направление:")
                                            color: "#222222"
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 125
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
                                            Layout.preferredWidth: 125
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
                                            Layout.preferredWidth: 125
                                        }
                                        StyledComboBox {
                                            id: studyFormCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.studyForms
                                        }
                                    }
                                }

                                // --- БЛОК УНИВЕРСИТЕТА: 2 ЦЭ (язык + профильный) + 1 ЦТ ---
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
                                        Layout.topMargin: 6
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        text: qsTr("Приоритет при подборе специальностей ВУЗа отдаётся бюджетной форме обучения.")
                                        color: "dimgray"
                                        font.family: "Arial"
                                        font.pointSize: 11
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
                                            Layout.preferredWidth: 96
                                        }
                                        StyledComboBox {
                                            id: ceLangSubjectCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.languageExamSubjects
                                            currentIndex: 0
                                        }
                                        StyledTextField {
                                            id: ceLangScoreField
                                            Layout.preferredWidth: 96
                                            placeholderText: qsTr("0–100")
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 0; top: 100 }
                                        }
                                    }

                                    // ЦЭ 2: профильные предметы (без Русского и Белорусского)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("ЦЭ 2:")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 96
                                        }
                                        StyledComboBox {
                                            id: ceProfileSubjectCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.profileExamSubjects
                                            currentIndex: 0
                                        }
                                        StyledTextField {
                                            id: ceProfileScoreField
                                            Layout.preferredWidth: 96
                                            placeholderText: qsTr("0–100")
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 0; top: 100 }
                                        }
                                    }

                                    // ЦТ: профильные предметы (без Русского и Белорусского)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: qsTr("ЦТ:")
                                            color: "#222222"
                                            font.bold: true
                                            font.family: "Arial"
                                            font.pointSize: 12
                                            Layout.preferredWidth: 96
                                        }
                                        StyledComboBox {
                                            id: ctSubjectCombo
                                            Layout.fillWidth: true
                                            model: AppConstants.profileExamSubjects
                                            currentIndex: 1
                                        }
                                        StyledTextField {
                                            id: ctScoreField
                                            Layout.preferredWidth: 96
                                            placeholderText: qsTr("0–100")
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 0; top: 100 }
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
                                        onClicked: root.submitProfile()

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

                        // --- КАРТОЧКА 2: ИЗБРАННОЕ ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: profileScroll.isWide ? 360 : 400
                            Layout.fillHeight: profileScroll.isWide
                            Layout.alignment: Qt.AlignTop
                            implicitHeight: Math.max(favoritesCardColumn.implicitHeight + 40,
                                                     profileScroll.isWide ? 240 : 120)
                            color: "#ffffff"
                            border.color: "#e0e0e0"
                            border.width: 1
                            radius: 8

                            ColumnLayout {
                                id: favoritesCardColumn
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 20
                                spacing: 10

                                Text {
                                    text: qsTr("Избранное")
                                    color: "#222222"
                                    font.bold: true
                                    font.family: "Arial"
                                    font.pointSize: 20
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: qsTr("Здесь будет список предпочтительных Вам специальностей")
                                    font.family: "Arial"
                                    font.pointSize: 12
                                    color: "dimgray"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            // 2. ВКЛАДКА: ГЛАВНАЯ (адаптивная сетка карточек)
            Rectangle {
                id: homeTab
                color: "#fafafa"

                // Пустое состояние
                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 520)
                    spacing: 15
                    visible: recommendationsModel.count === 0 && !recommendationService.busy

                    Text {
                        text: qsTr("Добро пожаловать в систему!")
                        color: "#222222"
                        font.bold: true
                        font.family: "Arial"
                        font.pointSize: 16
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: qsTr("Здесь будет отображаться список рекомендуемых специальностей")
                        font.family: "Arial"
                        font.pointSize: 12
                        color: "gray"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                // Индикатор загрузки
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: recommendationService.busy

                    BusyIndicator {
                        running: recommendationService.busy
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: qsTr("Загрузка рекомендаций...")
                        font.family: "Arial"
                        font.pointSize: 12
                        color: "dimgray"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // Список подобранных специальностей (EducationOffer)
                ScrollView {
                    id: offersScroll
                    anchors.fill: parent
                    clip: true
                    contentWidth: availableWidth
                    visible: recommendationsModel.count > 0 && !recommendationService.busy
                    background: Rectangle { color: "#fafafa" }

                    ColumnLayout {
                        width: offersScroll.availableWidth
                        spacing: 14

                        Text {
                            text: qsTr("Рекомендуемые специальности")
                            color: "#222222"
                            font.bold: true
                            font.family: "Arial"
                            font.pointSize: 18
                            Layout.topMargin: 24
                            Layout.leftMargin: 24
                            Layout.rightMargin: 24
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            Layout.rightMargin: 24
                            Layout.bottomMargin: 24
                            columns: offersScroll.availableWidth >= 820 ? 2 : 1
                            columnSpacing: 14
                            rowSpacing: 14

                            Repeater {
                                model: recommendationsModel

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    implicitHeight: offerCardColumn.implicitHeight + 24
                                    color: "#ffffff"
                                    border.color: "#dcdcdc"
                                    border.width: 1
                                    radius: 6

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
                                                implicitWidth: scoreBadgeText.implicitWidth + 16
                                                implicitHeight: scoreBadgeText.implicitHeight + 8

                                                Text {
                                                    id: scoreBadgeText
                                                    anchors.centerIn: parent
                                                    text: qsTr("Проходной: %1").arg(model.passingScore)
                                                    color: "#ffffff"
                                                    font.bold: true
                                                    font.family: "Arial"
                                                    font.pointSize: 11
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
                                            spacing: 16

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