// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import audio.global 1.0

ShaderEffect {
    id: shader

    //properties for shader

    //not pass to shader
    readonly property vector3d defaultResolution: Qt.vector3d(shader.width, shader.height, shader.width / shader.height)
    function calcResolution(channel) {
        if (channel) {
            return Qt.vector3d(channel.width, channel.height, channel.width / channel.height);
        } else {
            return defaultResolution;
        }
    }
    //pass
    readonly property vector3d  iResolution: defaultResolution
    property vector3d   iColor : Qt.vector3d(1.0, 0, 0)
    property real       iTime: 0
    property real       iTimeDelta: 100
    property int        iFrame: 10
    property real       iFrameRate
    property vector4d   iMouse;
    property var iChannel0  //only Image or ShaderEffectSource
    property var iChannel1  //only Image or ShaderEffectSource
    property var iChannel2; //only Image or ShaderEffectSource
    property var iChannel3; //only Image or ShaderEffectSource
    property var        iChannelTime: [0, 1, 2, 3]
    property var        iChannelResolution: [calcResolution(iChannel0), calcResolution(iChannel1), calcResolution(iChannel2), calcResolution(iChannel3)]
    property vector4d   iDate;
    property real       iSampleRate: 44100
    signal sigPlaybackStatusChange(int playbackStatus)
    function playbackStatusChange(playbackStatus){
        if(playbackStatus === DmGlobal.Playing) {
            timer1.start();
        } else {
            timer1.stop();
        }
    }
    Component.onCompleted: {
        Presenter.playbackStatusChanged.connect(sigPlaybackStatusChange)
        shader.sigPlaybackStatusChange.connect(playbackStatusChange)
        if(Presenter.getPlaybackStatus() === DmGlobal.Playing){
            timer1.start();
        }
    }

    //properties for Qml controller
    property alias hoverEnabled: mouse.hoverEnabled
    property bool running: true
    function restart() {
        shader.iTime = 0
        running = true
        timer1.restart()
    }
    Timer {
        id: timer1
        running: false
        triggeredOnStart: true
        interval: 16
        repeat: true
        onTriggered: {
            shader.iTime += 0.016;
        }
    }
    Timer {
        running: shader.running
        interval: 100
        onTriggered: {
            sigShaderStatusChange(status);
        }
    }

    Timer {
        running: shader.running
        interval: 1000
        onTriggered: {
            var date = new Date();
            shader.iDate.x = date.getFullYear();
            shader.iDate.y = date.getMonth();
            shader.iDate.z = date.getDay();
            shader.iDate.w = date.getSeconds()
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onPositionChanged: {
            shader.iMouse.x = mouseX
            shader.iMouse.y = mouseY
        }
        onClicked: {
            shader.iMouse.z = mouseX
            shader.iMouse.w = mouseY
        }
    }
    // 如果环境是OpenGL ES2，默认的version是 version 110, 不需要写出来。
    // 比ES2更老的版本是ES 1.0 和 ES 1.1, 这种古董设备，还是不要玩Shader了吧。
    // ES2没有texture函数，要用旧的texture2D代替
    // 精度限定要写成float
    readonly property string gles2Ver: "
#define texture texture2D
#ifdef GL_ES
precision mediump float;
#endif
"
    // 如果环境是OpenGL ES3，version是 version 300 es
    // ES 3.1 ES 3.2也可以。
    // ES3可以用in out 关键字，gl_FragColor也可以用out fragColor取代
    // 精度限定要写成float
    readonly property string gles3Ver: "#version 300 es
#define varying in
#define gl_FragColor fragColor
precision mediump float;

out vec4 fragColor;
"
    // 如果环境是OpenGL Desktop 3.x，version这里参考Qt默认的version 150。大部分Desktop设备应该都是150
    // 150 即3.2版本，第一个区分Core和Compatibility的版本。Core是核心模式，只有核心api以减轻负担。相应的Compatibility是兼容模式，保留全部API以兼容低版本。
    // 可以用in out 关键字，gl_FragColor也可以用out fragColor取代
    // 精度限定抹掉，用默认的。不抹掉有些情况下会报错，不能通用。
    readonly property string gl3Ver: "#version 150
#define varying in
#define gl_FragColor fragColor
#define lowp
#define mediump
#define highp

out vec4 fragColor;
"
    // 如果环境是OpenGL Desktop 2.x，version这里就用2.0的version 110，即2.0版本
    // 2.x 没有texture函数，要用旧的texture2D代替
    readonly property string gl2Ver: "#version 130
#define texture texture2D
"

    property string versionString: {
        return gles2Ver
    }

    vertexShader: "
              uniform mat4 qt_Matrix;
              attribute vec4 qt_Vertex;
              attribute vec2 qt_MultiTexCoord0;
              varying vec2 qt_TexCoord0;
              varying vec4 vertex;
              void main() {
                  vertex = qt_Vertex;
                  gl_Position = qt_Matrix * vertex;
                  qt_TexCoord0 = qt_MultiTexCoord0;
              }"

    readonly property string forwardString: versionString + "
        varying vec2 qt_TexCoord0;
        varying vec4 vertex;
        uniform lowp   float qt_Opacity;

        uniform vec3   iColor;
        uniform vec3   iResolution;
        uniform float  iTime;
        uniform float  iTimeDelta;
        uniform int    iFrame;
        uniform float  iFrameRate;
        uniform float  iChannelTime[4];
        uniform vec3   iChannelResolution[4];
        uniform vec4   iMouse;
        uniform vec4    iDate;
        uniform float   iSampleRate;
        uniform sampler2D   iChannel0;
        uniform sampler2D   iChannel1;
        uniform sampler2D   iChannel2;
        uniform sampler2D   iChannel3;
    "
    readonly property string startCode: "
        void main(void)
        {
            mainImage(gl_FragColor, vec2(vertex.x, iResolution.y - vertex.y));
        }"
    readonly property string defaultPixelShader: "
        void mainImage(out vec4 fragColor, in vec2 fragCoord)
        {
            fragColor = vec4(fragCoord, fragCoord.x, fragCoord.y);
        }"
    property string pixelShader: ""
    fragmentShader: forwardString + (pixelShader ? pixelShader : defaultPixelShader) + startCode
}

