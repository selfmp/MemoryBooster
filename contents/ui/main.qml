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
    height: 490

    fullRepresentation: Item {
        anchors.fill: parent

        // --- Global Settings & State ---
        property int currentTab: 0 // 0: Simon, 1: Numbers, 2: Settings
        property int difficultyLevel: 1 // 0: Easy, 1: Medium, 2: Hard
        property int themeMode: 0 // 0: Classic, 1: Neon

        // Difficulty Configuration
        readonly property var speedConfig: [
            { flashDuration: 400, stepDelay: 600, showNumberTime: 1800 }, // Easy
            { flashDuration: 250, stepDelay: 400, showNumberTime: 1200 }, // Medium
            { flashDuration: 150, stepDelay: 250, showNumberTime: 700 }   // Hard
        ]

        readonly property var colorPalettes: [
            // Classic
            [ { c: "#e74c3c", active: "#ff7675" },
              { c: "#2ecc71", active: "#55efc4" },
              { c: "#3498db", active: "#74b9ff" },
              { c: "#f1c40f", active: "#ffeaa7" } ],
            // Neon
            [ { c: "#ff007f", active: "#ff77b4" },
              { c: "#00f0ff", active: "#9cffff" },
              { c: "#7928ca", active: "#b87aff" },
              { c: "#00df89", active: "#85ffcc" } ]
        ]

        // --- Inactivity Watcher (1 Minute) ---
        Timer {
            id: inactivityTimer
            interval: 60000 // 60 seconds
            repeat: false
            running: true
            onTriggered: {
                resetAllGames()
            }
        }

        function reportUserActivity() {
            inactivityTimer.restart()
        }

        function resetAllGames() {
            // Reset Simon
            simonView.sequence = []
            simonView.score = 0
            simonView.statusMsg = "Reset due to inactivity"
            simonView.inputBlocked = true
            sequencePlaybackTimer.stop()

            // Reset Numbers
            hideNumberTimer.stop()
            autoNextTimer.stop()
            numberView.userInput = ""
            numberView.generatedNumber = ""
            numberView.isShowingNumber = false
            numberView.inputAllowed = false
            numberView.currentLength = 3
            numberView.streak = 0
            numberView.feedbackText = "Reset due to inactivity"
            numberView.feedbackColor = Kirigami.Theme.textColor
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // --- Navigation Bar ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                QQC2.Button {
                    Layout.fillWidth: true
                    text: "Simon"
                    highlighted: currentTab === 0
                    onClicked: currentTab = 0
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    text: "Numbers"
                    highlighted: currentTab === 1
                    onClicked: currentTab = 1
                }
                QQC2.Button {
                    Layout.preferredWidth: 42
                    text: "⚙"
                    highlighted: currentTab === 2
                    onClicked: currentTab = 2
                }
            }

            // ==========================================
            // GAME 1: SIMON SAYS (COLOR SEQUENCE)
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
                property bool inputBlocked: true
                property string statusMsg: "Press Start to begin"
                property int score: 0

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                }

                Text {
                    text: simonView.statusMsg
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }

                // Color Grid
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

                // Sequence Step Timer
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
                        Plasmoid.configuration.correctSimons += 1
                        stepIndex++
                        if (stepIndex >= sequence.length) {
                            inputBlocked = true
                            score = sequence.length
                            statusMsg = "Correct! Level Up"
                            roundDelayTimer.restart()
                        }
                    } else {
                        inputBlocked = true
                        statusMsg = "Game Over! Best: " + score
                    }
                }

                Timer {
                    id: roundDelayTimer
                    interval: 700
                    onTriggered: simonView.startNextRound()
                }

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Score: " + simonView.score
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Corrects: " + Plasmoid.configuration.correctSimons
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 11
                    }
                }
                QQC2.Button {
                    text: "Start Game"
                    Layout.fillWidth: true
                    onClicked: {
                        simonView.sequence = []
                        simonView.score = 0
                        simonView.startNextRound()
                    }
                }
            }

            // ==========================================
            // GAME 2: FLASH NUMBERS (STREAK-BASED ADVANCE)
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

                Item { 
                    Layout.fillWidth: true
                    Layout.fillHeight: true 
                }

                Text {
                    text: numberView.feedbackText
                    color: numberView.feedbackColor
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter // معادل textAlign = TextAlignment.Center
                }
                
                // Display Area
                Rectangle {
                    Layout.fillWidth: true
                    height: 55
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: numberView.isShowingNumber
                              ? numberView.generatedNumber
                              : (numberView.userInput !== "" ? numberView.userInput : "...")
                        font.pixelSize: 24
                        font.bold: true
                        font.letterSpacing: 3
                        color: Kirigami.Theme.textColor
                    }
                }

                // Timer to hide number after flash duration
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

                // Timer for auto-advancing to the next round
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

                        // --- ذخیره در شمارنده دائمی ---
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
                        
                        // --- ثبت اشتباه در شمارنده دائمی ---
                        Plasmoid.configuration.totalMistakes += 1
                        
                        feedbackText = "Wrong! Ans: " + generatedNumber
                        feedbackColor = "#e74c3c"
                        streak = 0
                        currentLength = Math.max(3, currentLength - 1)
                    }
                }

                // On-Screen Keypad
                GridLayout {
                    columns: 3
                    Layout.alignment: Qt.AlignCenter
                    rowSpacing: 5
                    columnSpacing: 5

                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "⌫"]
                        QQC2.Button {
                            text: modelData
                            Layout.preferredWidth: 65
                            Layout.preferredHeight: 38
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

                Item { 
                    Layout.fillWidth: true
                    Layout.fillHeight: true 
                }

                // Stats Banner (Saved permanently)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

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
                    spacing: 0

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
                        Layout.preferredWidth: 80
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
            // SETTINGS & CUSTOMIZATION
            // ==========================================
            ColumnLayout {
                visible: currentTab === 2
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
                        onClicked: difficultyLevel = 0
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Medium"
                        checkable: true
                        checked: difficultyLevel === 1
                        onClicked: difficultyLevel = 1
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Hard"
                        checkable: true
                        checked: difficultyLevel === 2
                        onClicked: difficultyLevel = 2
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
                        onClicked: themeMode = 0
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: "Neon"
                        checkable: true
                        checked: themeMode === 1
                        onClicked: themeMode = 1
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.alternateBackgroundColor }

                QQC2.Button {
                    Layout.fillWidth: true
                    text: "Clear Stats"
                    onClicked: {
                        Plasmoid.configuration.totalMemorizedDigits = 0
                        Plasmoid.configuration.totalMistakes = 0
                        Plasmoid.configuration.correctRounds = 0
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
