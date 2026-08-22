/* === This file is part of Calamares - <https://calamares.io> ===
 *
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *
 *   Yaya OS slideshow — minimalist, on-brand (silver on black).
 */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 8000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        z: -1
    }

    Slide {
        Image {
            id: logo
            source: "yaya-welcome.png"
            width: 360
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: logo.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: 28
            text: qsTr("Installing Yaya OS — refurbished hardware, brand-new life.")
            color: "#cfd4da"
            font.pixelSize: 18
            wrapMode: Text.WordWrap
            width: presentation.width * 0.8
            horizontalAlignment: Text.Center
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: qsTr("Runs light. Built for 4 GB machines and up —\nno computer left behind.")
            color: "#cfd4da"
            font.pixelSize: 22
            wrapMode: Text.WordWrap
            width: presentation.width * 0.8
            horizontalAlignment: Text.Center
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: qsTr("Yours to own. Privacy-minded, free software,\nyour keys, your machine.")
            color: "#cfd4da"
            font.pixelSize: 22
            wrapMode: Text.WordWrap
            width: presentation.width * 0.8
            horizontalAlignment: Text.Center
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: qsTr("Need a hand? yaya.tech · yaya.cash")
            color: "#cfd4da"
            font.pixelSize: 20
            horizontalAlignment: Text.Center
        }
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() { }
}
