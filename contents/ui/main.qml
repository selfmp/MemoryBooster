import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    width: 340
    height: 510

    fullRepresentation: Item {
        anchors.fill: parent

        // --- Global Settings & State ---
        property int currentTab: 0 // 0: Simon, 1: Numbers, 2: Reverse, 3: Grid, 4: Stroop, 5: Math, 6: Missing, 7: 1-Back, 8: Settings
        property int difficultyLevel: 1 // 0: Easy, 1: Medium, 2: Hard
        property int themeMode: 0 // 0: Classic, 1: Neon

        readonly property var gameTitles: [
            "Simon Colors",
            "Flash Numbers",
            "Reverse Digits",
            "Grid Pattern",
            "Stroop Match",
            "Mental Math",
            "Missing Letter",
            "1-Back Recall"
        ]

        readonly property var speedConfig: [
            { flashDuration: 400, stepDelay: 600, showNumberTime: 1800, mathTime: 1300 }, // Easy
            { flashDuration: 250, stepDelay: 400, showNumberTime: 1200, mathTime: 950 },  // Medium
            { flashDuration: 150, stepDelay: 250, showNumberTime: 700,  mathTime: 650 }   // Hard
        ]

        readonly property var colorPalettes: [
            [ { c: "#e74c3c", active: "#ff7675" },
              { c: "#2ecc71", active: "#55efc4" },
              { c: "#3498db", active: "#74b9ff" },
              { c: "#f1c40f", active: "#ffeaa7" } ],
            [ { c: "#ff007f", active: "#ff77b4" },
              { c: "#00f0ff", active: "#9cffff" },
              { c: "#7928ca", active: "#b87aff" },
              { c: "#00df89", active: "#85ffcc" } ]
        ]

        // --- Inactivity Watcher (1 Minute) ---
        Timer {
            id: inactivityTimer
            interval: 60000
            repeat: false
            running: true
            onTriggered: resetAllGames()
        }

        function reportUserActivity() {
            inactivityTimer.restart()
        }

        function resetAllGames() {
            // Simon
            simonView.sequence = []
            simonView.score = 0
            simonView.streak = 0
            simonView.statusMsg = "Press Start to begin"
            simonView.inputBlocked = true
            sequencePlaybackTimer.stop()

            // Numbers
            hideNumberTimer.stop()
            autoNextTimer.stop()
            numberView.userInput = ""
            numberView.generatedNumber = ""
            numberView.isShowingNumber = false
            numberView.inputAllowed = false
            numberView.currentLength = 3
            numberView.streak = 0
            numberView.feedbackText = "Press Start to begin"
            numberView.feedbackColor = Kirigami.Theme.textColor

            // Reverse
            revHideTimer.stop()
            revNextTimer.stop()
            reverseView.userInput = ""
            reverseView.generatedNumber = ""
            reverseView.isShowingNumber = false
            reverseView.inputAllowed = false
            reverseView.currentLength = 3
            reverseView.streak = 0
            reverseView.feedbackText = "Press Start to begin"
            reverseView.feedbackColor = Kirigami.Theme.textColor

            // Grid
            gridTimer.stop()
            gridNextTimer.stop()
            gridView.targetIndices = []
            gridView.selectedIndices = []
            gridView.inputAllowed = false
            gridView.showingPattern = false
            gridView.levelCount = 3
            gridView.streak = 0
            gridView.feedbackText = "Press Start to see pattern"
            gridView.feedbackColor = Kirigami.Theme.textColor

            // Stroop
            stroopAdvanceTimer.stop()
            stroopView.streak = 0
            stroopView.feedbackText = "Pick the font color!"
            stroopView.feedbackColor = Kirigami.Theme.textColor

            // Math
            mathStepTimer.stop()
            mathNextTimer.stop()
            mathView.runningMath = false
            mathView.streak = 0
            mathView.mathOptions = []
            mathView.currentPrompt = "Ready"
            mathView.feedbackText = "Press Start"
            mathView.feedbackColor = Kirigami.Theme.textColor

            // Missing
            missingTimer.stop()
            missingNextTimer.stop()
            missingView.streak = 0
            missingView.inputAllowed = false
            missingView.displayedSet = ""
            missingView.feedbackText = "Press Start"
            missingView.feedbackColor = Kirigami.Theme.textColor

            // N-Back
            nbackTimer.stop()
            nbackView.isPlaying = false
            nbackView.streak = 0
            nbackView.score = 0
            nbackView.currentItem = ""
            nbackView.prevItem = ""
            nbackView.feedbackText = "Press Start"
            nbackView.feedbackColor = Kirigami.Theme.textColor
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // --- Header & Navigation Bar ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                QQC2.ComboBox {
                    id: gameSelector
                    Layout.fillWidth: true
                    model: gameTitles
                    currentIndex: currentTab < 8 ? currentTab : 0
                    onActivated: (index) => {
                        reportUserActivity()
                        currentTab = index
                    }
                }

                QQC2.Button {
                    Layout.preferredWidth: 42
                    text: "⚙"
                    highlighted: currentTab === 8
                    onClicked: {
                        reportUserActivity()
                        currentTab = currentTab === 8 ? gameSelector.currentIndex : 8
                    }
                }
            }

            // ==========================================
            // GAME 1: SIMON SAYS
            // ==========================================
            ColumnLayout {
                id: simonView
                visible: currentTab === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                property var sequence: []
                property int playIndex: 0
                property int stepIndex: 0
                property int streak: 0
                readonly property int requiredStreak: 3
                property bool inputBlocked: true
                property string statusMsg: "Press Start to begin"
                property int score: 0

                Item { Layout.fillHeight: true; Layout.fillWidth: true }

                Text {
                    text: simonView.statusMsg
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }

                GridLayout {
                    columns: 2
                    Layout.alignment: Qt.AlignCenter
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        id: padRepeater
                        model: 4

                        Rectangle {
                            id: pad
                            width: 85
                            height: 85
                            radius: 14
                            property bool isFlashing: false
                            property var currentPalette: colorPalettes[themeMode][index]
                            color: isFlashing ? currentPalette.active : currentPalette.c
                            opacity: isFlashing ? 1.0 : 0.65
                            scale: isFlashing ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on opacity { NumberAnimation { duration: 80 } }

                            function triggerFlash(duration) {
                                isFlashing = true
                                flashTimer.interval = duration
                                flashTimer.restart()
                            }

                            Timer {
                                id: flashTimer
                                onTriggered: pad.isFlashing = false
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !simonView.inputBlocked
                                onClicked: {
                                    reportUserActivity()
                                    pad.triggerFlash(speedConfig[difficultyLevel].flashDuration)
                                    simonView.handleInput(index)
                                }
                            }
                        }
                    }
                }

                Timer {
                    id: sequencePlaybackTimer
                    interval: speedConfig[difficultyLevel].stepDelay
                    onTriggered: {
                        if (simonView.playIndex < simonView.sequence.length) {
                            var padIndex = simonView.sequence[simonView.playIndex]
                            padRepeater.itemAt(padIndex).triggerFlash(speedConfig[difficultyLevel].flashDuration)
                            simonView.playIndex++
                            sequencePlaybackTimer.restart()
                        } else {
                            simonView.inputBlocked = false
                            simonView.statusMsg = "Your Turn!"
                        }
                    }
                }

                function startNextRound() {
                    inputBlocked = true
                    sequence.push(Math.floor(Math.random() * 4))
                    playIndex = 0
                    stepIndex = 0
                    statusMsg = "Watch carefully..."
                    sequencePlaybackTimer.start()
                }

                function handleInput(clickedIndex) {
                    if (clickedIndex === sequence[stepIndex]) {
                        stepIndex++
                        if (stepIndex >= sequence.length) {
                            inputBlocked = true
                            score = sequence.length
                            Plasmoid.configuration.correctSimons += 1
                            streak++
                            if (streak >= requiredStreak) {
                                statusMsg = "Correct! Level Up!"
                                streak = 0
                            } else {
                                statusMsg = "Correct! (" + streak + "/" + requiredStreak + ")"
                            }
                            roundDelayTimer.restart()
                        }
                    } else {
                        inputBlocked = true
                        streak = 0
                        statusMsg = "Game Over! Best: " + score
                    }
                }

                Timer {
                    id: roundDelayTimer
                    interval: 700
                    onTriggered: simonView.startNextRound()
                }

                Item { Layout.fillHeight: true; Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Score: " + simonView.score
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Total Steps: " + Plasmoid.configuration.correctSimons
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: "Start Game"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            simonView.sequence = []
                            simonView.score = 0
                            simonView.streak = 0
                            simonView.startNextRound()
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // GAME 2: FLASH NUMBERS
            // ==========================================
            ColumnLayout {
                id: numberView
                visible: currentTab === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                property int currentLength: 3
                property int streak: 0
                readonly property int requiredStreak: 3
                property string generatedNumber: ""
                property string userInput: ""
                property bool isShowingNumber: false
                property bool inputAllowed: false
                property string feedbackText: "Press Start to begin"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillWidth: true; Layout.fillHeight: true }

                Text {
                    text: numberView.feedbackText
                    color: numberView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: numberView.isShowingNumber
                              ? numberView.generatedNumber
                              : (numberView.userInput !== "" ? numberView.userInput : "...")
                        font.pixelSize: 22
                        font.bold: true
                        font.letterSpacing: 3
                        color: Kirigami.Theme.textColor
                    }
                }

                Timer {
                    id: hideNumberTimer
                    interval: speedConfig[difficultyLevel].showNumberTime
                    onTriggered: {
                        numberView.isShowingNumber = false
                        numberView.userInput = ""
                        numberView.inputAllowed = true
                        numberView.feedbackText = "Type the number"
                        numberView.feedbackColor = Kirigami.Theme.textColor
                    }
                }

                Timer {
                    id: autoNextTimer
                    interval: 800
                    onTriggered: numberView.startRound()
                }

                function startRound() {
                    var res = ""
                    for (var i = 0; i < currentLength; i++) {
                        res += Math.floor(Math.random() * 10).toString()
                    }
                    generatedNumber = res
                    userInput = ""
                    inputAllowed = false
                    feedbackText = "Memorize!"
                    feedbackColor = Kirigami.Theme.textColor
                    isShowingNumber = true
                    hideNumberTimer.restart()
                }

                function checkCurrentInput() {
                    if (userInput === generatedNumber) {
                        inputAllowed = false
                        Plasmoid.configuration.totalMemorizedDigits += currentLength
                        Plasmoid.configuration.correctRounds += 1
                        streak++
                        if (streak >= requiredStreak) {
                            currentLength++
                            streak = 0
                            feedbackText = "Level Up! +1 Digit"
                        } else {
                            feedbackText = "Correct! (" + streak + "/" + requiredStreak + ")"
                        }
                        feedbackColor = "#2ecc71"
                        autoNextTimer.restart()
                    } else {
                        inputAllowed = false
                        feedbackText = "Wrong! Ans: " + generatedNumber
                        feedbackColor = "#e74c3c"
                        streak = 0
                        currentLength = Math.max(3, currentLength - 1)
                    }
                }

                GridLayout {
                    columns: 3
                    Layout.alignment: Qt.AlignCenter
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "⌫"]
                        QQC2.Button {
                            text: modelData
                            Layout.preferredWidth: 62
                            Layout.preferredHeight: 36
                            enabled: numberView.inputAllowed

                            onClicked: {
                                reportUserActivity()
                                if (modelData === "C") {
                                    numberView.userInput = ""
                                } else if (modelData === "⌫") {
                                    if (numberView.userInput.length > 0) {
                                        numberView.userInput = numberView.userInput.slice(0, -1)
                                    }
                                } else {
                                    numberView.userInput += modelData
                                    if (numberView.userInput.length === numberView.generatedNumber.length) {
                                        numberView.checkCurrentInput()
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Digits: " + numberView.currentLength + " (" + numberView.streak + "/" + numberView.requiredStreak + ")"
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Memorized: " + Plasmoid.configuration.correctRounds
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        Layout.fillWidth: true
                        text: numberView.inputAllowed || numberView.isShowingNumber ? "Restart Round" : "Start Game"
                        onClicked: {
                            reportUserActivity()
                            numberView.streak = 0
                            numberView.startRound()
                        }
                    }

                    QQC2.Button {
                        Layout.preferredWidth: 70
                        text: "Reset"
                        onClicked: {
                            reportUserActivity()
                            hideNumberTimer.stop()
                            autoNextTimer.stop()
                            numberView.userInput = ""
                            numberView.generatedNumber = ""
                            numberView.isShowingNumber = false
                            numberView.inputAllowed = false
                            numberView.currentLength = 3
                            numberView.streak = 0
                            numberView.feedbackText = "Game Reset"
                            numberView.feedbackColor = Kirigami.Theme.textColor
                        }
                    }
                }
            }

            // ==========================================
            // GAME 3: REVERSE DIGITS
            // ==========================================
            ColumnLayout {
                id: reverseView
                visible: currentTab === 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                property int currentLength: 3
                property int streak: 0
                readonly property int requiredStreak: 3
                property string generatedNumber: ""
                property string userInput: ""
                property bool isShowingNumber: false
                property bool inputAllowed: false
                property string feedbackText: "Press Start to begin"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillWidth: true; Layout.fillHeight: true }

                Text {
                    text: reverseView.feedbackText
                    color: reverseView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: reverseView.isShowingNumber
                              ? reverseView.generatedNumber
                              : (reverseView.userInput !== "" ? reverseView.userInput : "...")
                        font.pixelSize: 22
                        font.bold: true
                        font.letterSpacing: 3
                        color: Kirigami.Theme.textColor
                    }
                }

                Timer {
                    id: revHideTimer
                    interval: speedConfig[difficultyLevel].showNumberTime
                    onTriggered: {
                        reverseView.isShowingNumber = false
                        reverseView.userInput = ""
                        reverseView.inputAllowed = true
                        reverseView.feedbackText = "Type in REVERSE!"
                        reverseView.feedbackColor = Kirigami.Theme.textColor
                    }
                }

                Timer {
                    id: revNextTimer
                    interval: 800
                    onTriggered: reverseView.startRound()
                }

                function startRound() {
                    var res = ""
                    for (var i = 0; i < currentLength; i++) {
                        res += Math.floor(Math.random() * 10).toString()
                    }
                    generatedNumber = res
                    userInput = ""
                    inputAllowed = false
                    feedbackText = "Memorize!"
                    feedbackColor = Kirigami.Theme.textColor
                    isShowingNumber = true
                    revHideTimer.restart()
                }

                function checkCurrentInput() {
                    var reversedTarget = generatedNumber.split("").reverse().join("")
                    if (userInput === reversedTarget) {
                        inputAllowed = false
                        Plasmoid.configuration.correctReverse += 1
                        streak++
                        if (streak >= requiredStreak) {
                            currentLength++
                            streak = 0
                            feedbackText = "Level Up! +1 Digit"
                        } else {
                            feedbackText = "Correct! (" + streak + "/" + requiredStreak + ")"
                        }
                        feedbackColor = "#2ecc71"
                        revNextTimer.restart()
                    } else {
                        inputAllowed = false
                        feedbackText = "Wrong! Answer: " + reversedTarget
                        feedbackColor = "#e74c3c"
                        streak = 0
                        currentLength = Math.max(3, currentLength - 1)
                    }
                }

                GridLayout {
                    columns: 3
                    Layout.alignment: Qt.AlignCenter
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "⌫"]
                        QQC2.Button {
                            text: modelData
                            Layout.preferredWidth: 62
                            Layout.preferredHeight: 36
                            enabled: reverseView.inputAllowed

                            onClicked: {
                                reportUserActivity()
                                if (modelData === "C") {
                                    reverseView.userInput = ""
                                } else if (modelData === "⌫") {
                                    if (reverseView.userInput.length > 0) {
                                        reverseView.userInput = reverseView.userInput.slice(0, -1)
                                    }
                                } else {
                                    reverseView.userInput += modelData
                                    if (reverseView.userInput.length === reverseView.generatedNumber.length) {
                                        reverseView.checkCurrentInput()
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Length: " + reverseView.currentLength + " (" + reverseView.streak + "/" + reverseView.requiredStreak + ")"
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Mistakes: " + Plasmoid.configuration.totalMistakes
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: reverseView.inputAllowed || reverseView.isShowingNumber ? "Restart Round" : "Start Reverse"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            reverseView.streak = 0
                            reverseView.startRound()
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // GAME 4: GRID MEMORY (PATTERN)
            // ==========================================
            ColumnLayout {
                id: gridView
                visible: currentTab === 3
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                property int levelCount: 3
                property int streak: 0
                readonly property int requiredStreak: 3
                property var targetIndices: []
                property var selectedIndices: []
                property bool showingPattern: false
                property bool inputAllowed: false
                property string feedbackText: "Press Start to see pattern"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillHeight: true }

                Text {
                    text: gridView.feedbackText
                    color: gridView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                GridLayout {
                    columns: 3
                    Layout.alignment: Qt.AlignCenter
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: 9
                        Rectangle {
                            id: cell
                            width: 60
                            height: 60
                            radius: 8

                            property bool isTarget: gridView.targetIndices.indexOf(index) !== -1
                            property bool isSelected: gridView.selectedIndices.indexOf(index) !== -1

                            color: (gridView.showingPattern && isTarget) || isSelected
                                   ? Kirigami.Theme.highlightColor
                                   : Kirigami.Theme.alternateBackgroundColor

                            MouseArea {
                                anchors.fill: parent
                                enabled: gridView.inputAllowed && !cell.isSelected
                                onClicked: {
                                    reportUserActivity()
                                    gridView.handleCellClick(index)
                                }
                            }
                        }
                    }
                }

                Timer {
                    id: gridTimer
                    interval: 1200
                    onTriggered: {
                        gridView.showingPattern = false
                        gridView.inputAllowed = true
                        gridView.feedbackText = "Pick the " + gridView.levelCount + " tiles!"
                    }
                }

                Timer {
                    id: gridNextTimer
                    interval: 800
                    onTriggered: gridView.startRound()
                }

                function startRound() {
                    var newTargets = []
                    while (newTargets.length < levelCount) {
                        var rand = Math.floor(Math.random() * 9)
                        if (newTargets.indexOf(rand) === -1) {
                            newTargets.push(rand)
                        }
                    }

                    targetIndices = newTargets.slice()
                    selectedIndices = []
                    inputAllowed = false
                    showingPattern = true
                    feedbackText = "Memorize tiles!"
                    feedbackColor = Kirigami.Theme.textColor
                    gridTimer.stop()
                    gridTimer.restart()
                }

                function handleCellClick(idx) {
                    if (targetIndices.indexOf(idx) !== -1) {
                        var newSelection = selectedIndices.slice()
                        newSelection.push(idx)
                        selectedIndices = newSelection

                        if (selectedIndices.length === targetIndices.length) {
                            inputAllowed = false
                            streak++
                            if (streak >= requiredStreak) {
                                feedbackText = "Pattern Complete! Level Up!"
                                feedbackColor = "#2ecc71"
                                levelCount = Math.min(7, levelCount + 1)
                                streak = 0
                            } else {
                                feedbackText = "Pattern Complete! (" + streak + "/" + requiredStreak + ")"
                                feedbackColor = "#2ecc71"
                            }
                            Plasmoid.configuration.correctGrid += 1
                            showingPattern = false
                            gridNextTimer.restart()
                        }
                    } else {
                        inputAllowed = false
                        feedbackText = "Wrong tile! Resetting..."
                        feedbackColor = "#e74c3c"
                        selectedIndices = []
                        streak = 0
                        levelCount = Math.max(3, levelCount - 1)
                        showingPattern = false
                        gridNextTimer.restart()
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Tiles: " + gridView.levelCount + " (" + gridView.streak + "/" + gridView.requiredStreak + ")"
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Solved: " + Plasmoid.configuration.correctGrid
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: "Start Pattern"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            gridView.streak = 0
                            gridView.startRound()
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // GAME 5: STROOP TEST
            // ==========================================
            ColumnLayout {
                id: stroopView
                visible: currentTab === 4
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                readonly property var colorList: [
                    { name: "RED", c: "#e74c3c" },
                    { name: "BLUE", c: "#3498db" },
                    { name: "GREEN", c: "#2ecc71" },
                    { name: "YELLOW", c: "#f1c40f" }
                ]

                property int textColorIndex: 0
                property int textMeaningIndex: 0
                property int streak: 0
                readonly property int requiredStreak: 3
                property string feedbackText: "Pick the FONT COLOR, not the word!"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillHeight: true }

                Text {
                    text: stroopView.feedbackText
                    color: stroopView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 10

                    Text {
                        anchors.centerIn: parent
                        text: stroopView.colorList[stroopView.textMeaningIndex].name
                        color: stroopView.colorList[stroopView.textColorIndex].c
                        font.pixelSize: 36
                        font.bold: true
                    }
                }

                function nextChallenge() {
                    textMeaningIndex = Math.floor(Math.random() * colorList.length)
                    textColorIndex = Math.floor(Math.random() * colorList.length)
                }

                Timer {
                    id: stroopAdvanceTimer
                    interval: 700
                    onTriggered: stroopView.nextChallenge()
                }

                function chooseColor(idx) {
                    if (idx === textColorIndex) {
                        streak++
                        if (streak >= requiredStreak) {
                            feedbackText = "Fast & Correct! Level Up!"
                            feedbackColor = "#2ecc71"
                            streak = 0
                        } else {
                            feedbackText = "Fast & Correct! (" + streak + "/" + requiredStreak + ")"
                            feedbackColor = "#2ecc71"
                        }
                        Plasmoid.configuration.correctStroop += 1
                    } else {
                        streak = 0
                        feedbackText = "Wrong! Matched color: " + colorList[textColorIndex].name
                        feedbackColor = "#e74c3c"
                    }
                    stroopAdvanceTimer.restart()
                }

                GridLayout {
                    columns: 2
                    Layout.alignment: Qt.AlignCenter
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: stroopView.colorList
                        QQC2.Button {
                            text: modelData.name
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            onClicked: {
                                reportUserActivity()
                                stroopView.chooseColor(index)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Score: " + Plasmoid.configuration.correctStroop + " (" + stroopView.streak + "/" + stroopView.requiredStreak + ")"
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: "New Challenge"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            stroopView.streak = 0
                            stroopView.nextChallenge()
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // GAME 6: MENTAL MATH CHAIN
            // ==========================================
            ColumnLayout {
                id: mathView
                visible: currentTab === 5
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                property int currentVal: 0
                property int mathStep: 0
                property int targetTotal: 0
                property int streak: 0
                readonly property int requiredStreak: 3
                property string currentPrompt: "Ready"
                property bool runningMath: false
                property string feedbackText: "Chain calculations mentally"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillHeight: true }

                Text {
                    text: mathView.feedbackText
                    color: mathView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 65
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: mathView.currentPrompt
                        font.pixelSize: 28
                        font.bold: true
                        color: Kirigami.Theme.textColor
                    }
                }

                Timer {
                    id: mathStepTimer
                    interval: speedConfig[difficultyLevel].mathTime
                    onTriggered: {
                        mathView.mathStep++
                        if (mathView.mathStep === 1) {
                            var op1 = Math.floor(Math.random() * 8) + 1
                            mathView.targetTotal += op1
                            mathView.currentPrompt = "+ " + op1
                            mathStepTimer.restart()
                        } else if (mathView.mathStep === 2) {
                            var op2 = Math.floor(Math.random() * 5) + 1
                            mathView.targetTotal -= op2
                            mathView.currentPrompt = "- " + op2
                            mathStepTimer.restart()
                        } else {
                            mathView.currentPrompt = "Total = ?"
                            mathView.runningMath = false
                            mathView.generateOptions()
                        }
                    }
                }

                Timer {
                    id: mathNextTimer
                    interval: 900
                    onTriggered: mathView.startMath()
                }

                property var mathOptions: []

                function generateOptions() {
                    var opts = [targetTotal, targetTotal + 2, targetTotal - 1]
                    opts.sort(() => Math.random() - 0.5)
                    mathOptions = opts
                }

                function startMath() {
                    targetTotal = Math.floor(Math.random() * 10) + 5
                    currentPrompt = targetTotal.toString()
                    mathStep = 0
                    runningMath = true
                    mathOptions = []
                    feedbackText = "Remember..."
                    feedbackColor = Kirigami.Theme.textColor
                    mathStepTimer.restart()
                }

                function handleChoice(choiceValue) {
                    mathView.currentPrompt = choiceValue
                    if (choiceValue === targetTotal) {
                        streak++
                        if (streak >= requiredStreak) {
                            feedbackText = "Correct calculation! Level Up!"
                            feedbackColor = "#2ecc71"
                            streak = 0
                        } else {
                            feedbackText = "Correct calculation! (" + streak + "/" + requiredStreak + ")"
                            feedbackColor = "#2ecc71"
                        }
                        Plasmoid.configuration.correctMath += 1
                    } else {
                        streak = 0
                        feedbackText = "Wrong! Total was " + targetTotal
                        feedbackColor = "#e74c3c"
                    }
                    mathOptions = []
                    mathNextTimer.restart()
                }

                RowLayout {
                    Layout.alignment: Qt.AlignCenter
                    spacing: 8
                    visible: !mathView.runningMath && mathView.mathOptions.length > 0

                    Repeater {
                        model: mathView.mathOptions
                        QQC2.Button {
                            text: modelData.toString()
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 40
                            onClicked: {
                                reportUserActivity()
                                mathView.handleChoice(modelData)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Solved: " + Plasmoid.configuration.correctMath + " (" + mathView.streak + "/" + mathView.requiredStreak + ")"
                    color: Kirigami.Theme.highlightColor
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: "Start"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            mathView.streak = 0
                            mathView.startMath()
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // GAME 7: MISSING LETTER
            // ==========================================
            ColumnLayout {
                id: missingView
                visible: currentTab === 6
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                property string originalSet: ""
                property string missingChar: ""
                property string displayedSet: ""
                property int streak: 0
                readonly property int requiredStreak: 3
                property bool inputAllowed: false
                property string feedbackText: "Find what vanished"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillHeight: true }

                Text {
                    text: missingView.feedbackText
                    color: missingView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: missingView.displayedSet !== "" ? missingView.displayedSet : "..."
                        font.pixelSize: 26
                        font.bold: true
                        font.letterSpacing: 6
                        color: Kirigami.Theme.textColor
                    }
                }

                Timer {
                    id: missingTimer
                    interval: 1400
                    onTriggered: {
                        var arr = missingView.originalSet.split(" ")
                        var removeIdx = Math.floor(Math.random() * arr.length)
                        missingView.missingChar = arr[removeIdx]
                        arr.splice(removeIdx, 1)
                        arr.sort(() => Math.random() - 0.5)
                        missingView.displayedSet = arr.join(" ")
                        missingView.inputAllowed = true
                        missingView.feedbackText = "Which letter is missing?"
                    }
                }

                Timer {
                    id: missingNextTimer
                    interval: 900
                    onTriggered: missingView.startMissing()
                }

                function startMissing() {
                    var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ"
                    var chosen = []
                    while (chosen.length < 4) {
                        var c = chars[Math.floor(Math.random() * chars.length)]
                        if (chosen.indexOf(c) === -1) chosen.push(c)
                    }
                    originalSet = chosen.join(" ")
                    displayedSet = originalSet
                    inputAllowed = false
                    feedbackText = "Memorize letters!"
                    feedbackColor = Kirigami.Theme.textColor
                    missingTimer.restart()
                }

                RowLayout {
                    Layout.alignment: Qt.AlignCenter
                    spacing: 6
                    visible: missingView.inputAllowed

                    Repeater {
                        model: missingView.originalSet.split(" ")
                        QQC2.Button {
                            text: modelData
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 38
                            onClicked: {
                                reportUserActivity()
                                if (modelData === missingView.missingChar) {
                                    missingView.streak++
                                    if (missingView.streak >= missingView.requiredStreak) {
                                        missingView.feedbackText = "Sharp Eye! Level Up!"
                                        missingView.feedbackColor = "#2ecc71"
                                        missingView.streak = 0
                                    } else {
                                        missingView.feedbackText = "Sharp Eye! (" + missingView.streak + "/" + missingView.requiredStreak + ")"
                                        missingView.feedbackColor = "#2ecc71"
                                    }
                                    Plasmoid.configuration.correctMissing += 1
                                } else {
                                    missingView.streak = 0
                                    missingView.feedbackText = "Wrong! Missing: " + missingView.missingChar
                                    missingView.feedbackColor = "#e74c3c"
                                }
                                missingView.inputAllowed = false
                                missingNextTimer.restart()
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Solved: " + Plasmoid.configuration.correctMissing + " (" + missingView.streak + "/" + missingView.requiredStreak + ")"
                    color: Kirigami.Theme.highlightColor
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: "Start Round"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            missingView.streak = 0
                            missingView.startMissing()
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // GAME 8: 1-BACK RECALL
            // ==========================================
            ColumnLayout {
                id: nbackView
                visible: currentTab === 7
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                property string prevItem: ""
                property string currentItem: ""
                property string displayItem: "READY"
                property bool isPlaying: false
                property int score: 0
                property int streak: 0
                readonly property int requiredStreak: 3
                property string feedbackText: "Press Match if same as PREVIOUS"
                property color feedbackColor: Kirigami.Theme.textColor

                Item { Layout.fillHeight: true }

                Text {
                    text: nbackView.feedbackText
                    color: nbackView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 70
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 8

                    Text {
                        id: nbackLetter
                        anchors.centerIn: parent
                        text: nbackView.displayItem
                        font.pixelSize: 34
                        font.bold: true
                        color: Kirigami.Theme.highlightColor
                        opacity: 1
                        scale: 1
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                        onTextChanged: {
                            nbackLetter.opacity = 0.2
                            nbackLetter.scale = 0.7
                            nbackLetterFadeTimer.restart()
                        }

                        Timer {
                            id: nbackLetterFadeTimer
                            interval: 120
                            onTriggered: {
                                nbackLetter.opacity = 1
                                nbackLetter.scale = 1
                            }
                        }
                    }
                }

                Timer {
                    id: nbackTimer
                    interval: 1800
                    repeat: true
                    onTriggered: {
                        nbackView.prevItem = nbackView.currentItem
                        var letters = ["A", "B", "C", "D"]
                        var nextItem = ""

                        if (nbackView.prevItem !== "" && Math.random() < 0.35) {
                            nextItem = nbackView.prevItem
                        } else {
                            nextItem = letters[Math.floor(Math.random() * letters.length)]
                            if (nbackView.prevItem !== "" && nextItem === nbackView.prevItem) {
                                var alternate = letters.filter(function (letter) { return letter !== nextItem })
                                if (alternate.length > 0) {
                                    nextItem = alternate[Math.floor(Math.random() * alternate.length)]
                                }
                            }
                        }

                        nbackView.displayItem = ""
                        nbackView.currentItem = nextItem
                        nbackView.displayItem = nextItem
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignCenter
                    spacing: 12
                    visible: nbackView.isPlaying

                    QQC2.Button {
                        text: "MATCH!"
                        highlighted: true
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 42
                        onClicked: {
                            reportUserActivity()
                            if (nbackView.currentItem === nbackView.prevItem && nbackView.prevItem !== "") {
                                nbackView.streak++
                                if (nbackView.streak >= nbackView.requiredStreak) {
                                    nbackView.score++
                                    nbackView.feedbackText = "Good Catch! Level Up!"
                                    nbackView.feedbackColor = "#2ecc71"
                                    nbackView.streak = 0
                                } else {
                                    nbackView.feedbackText = "Good Catch! (" + nbackView.streak + "/" + nbackView.requiredStreak + ")"
                                    nbackView.feedbackColor = "#2ecc71"
                                }
                                Plasmoid.configuration.correctNBack += 1
                            } else {
                                nbackView.streak = 0
                                nbackView.feedbackText = "Missed! Not equal"
                                nbackView.feedbackColor = "#e74c3c"
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Score: " + nbackView.score + " (" + nbackView.streak + "/" + nbackView.requiredStreak + ")"
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Total Hits: " + Plasmoid.configuration.correctNBack
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Button {
                        text: nbackView.isPlaying ? "Stop" : "Start 1-Back"
                        Layout.fillWidth: true
                        onClicked: {
                            reportUserActivity()
                            if (nbackView.isPlaying) {
                                nbackTimer.stop()
                                nbackView.isPlaying = false
                                nbackView.currentItem = ""
                                nbackView.prevItem = ""
                                nbackView.displayItem = "READY"
                            } else {
                                nbackView.score = 0
                                nbackView.streak = 0
                                nbackView.isPlaying = true
                                nbackView.displayItem = "READY"
                                nbackView.feedbackText = "Watch carefully..."
                                nbackTimer.restart()
                            }
                        }
                    }

                    QQC2.Button {
                        text: "Reset"
                        Layout.preferredWidth: 70
                        onClicked: {
                            reportUserActivity()
                            resetAllGames()
                        }
                    }
                }
            }

            // ==========================================
            // SETTINGS & CUSTOMIZATION
            // ==========================================
            ColumnLayout {
                visible: currentTab === 8
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Text {
                    text: "Difficulty Level"
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Easy"
                        checkable: true
                        checked: difficultyLevel === 0
                        onClicked: { reportUserActivity(); difficultyLevel = 0 }
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Medium"
                        checkable: true
                        checked: difficultyLevel === 1
                        onClicked: { reportUserActivity(); difficultyLevel = 1 }
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Hard"
                        checkable: true
                        checked: difficultyLevel === 2
                        onClicked: { reportUserActivity(); difficultyLevel = 2 }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.alternateBackgroundColor }

                Text {
                    text: "Color Palette (Simon)"
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Classic"
                        checkable: true
                        checked: themeMode === 0
                        onClicked: { reportUserActivity(); themeMode = 0 }
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Neon"
                        checkable: true
                        checked: themeMode === 1
                        onClicked: { reportUserActivity(); themeMode = 1 }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.alternateBackgroundColor }

                QQC2.Button {
                    Layout.fillWidth: true
                    text: "Clear All Saved Stats"
                    onClicked: {
                        reportUserActivity()
                        Plasmoid.configuration.correctSimons = 0
                        Plasmoid.configuration.totalMemorizedDigits = 0
                        Plasmoid.configuration.totalMistakes = 0
                        Plasmoid.configuration.correctRounds = 0
                        Plasmoid.configuration.correctGrid = 0
                        Plasmoid.configuration.correctStroop = 0
                        Plasmoid.configuration.correctMath = 0
                        Plasmoid.configuration.correctMissing = 0
                        Plasmoid.configuration.correctNBack = 0
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Changes apply immediately."
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}