/*
Copyright (c) 2022 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/
module main;

import std.stdio;
import std.conv;
import std.string;
import std.math;
import dlib.math;
import dlib.image;

import minigl;
import bindbc.sdl;
import keycodes;

struct Timer
{
    double deltaTime = 0.0;
    double averageDelta = 0.0;
    uint deltaTimeMs = 0;
    int fps = 0;
    
    int currentTime;
    int lastTime;
    int FPSTickCounter;
    int FPSCounter = 0;
    
    void update()
    {
        static int currentTime;
        static int lastTime;

        static int FPSTickCounter;
        static int FPSCounter = 0;

        currentTime = SDL_GetTicks();
        auto elapsedTime = currentTime - lastTime;
        lastTime = currentTime;
        deltaTimeMs = elapsedTime;
        deltaTime = cast(double)(elapsedTime) * 0.001;

        FPSTickCounter += elapsedTime;
        FPSCounter++;
        if (FPSTickCounter >= 1000) // 1 sec interval
        {
            fps = FPSCounter;
            FPSCounter = 0;
            FPSTickCounter = 0;
            averageDelta = 1.0 / cast(double)(fps);
        }
    }
}

struct LevelSegment
{
    float x;
    float y;
    float z;
    uint textureId;
    float angle;
}

float clampf(float v, float mi, float ma)
{
    if (v < mi) return mi;
    else if (v > ma) return ma;
    else return v; 
}

FSOut psRed(const ref MGLPipelineState state, Vector4f coords, Vector2f uv)
{
    float t = state.shaderParameters[0].x;
    Color4f col = state.textureSample(state.texture, uv) * 
        lerp(Color4f(1.0f, 1.0f, 1.0f, 1.0f), Color4f(1.0f, 0.0f, 0.0f, 1.0f), t);
    if (state.options[MGL_FOG])
    {
        float fogDistance = coords.w;
        float fogFactor = clampf((state.fogEnd - fogDistance) / (state.fogEnd - state.fogStart), 0.0f, 1.0f);
        Color4f fogColor = state.fogColor;
        col = lerp(fogColor, col, fogFactor);
    }
    return FSOut(col);
}

void main()
{
    SDLSupport sdlsup = loadSDL();
    if (sdlsup != sdlSupport)
    {
        if (sdlsup != SDLSupport.badLibrary)
        {
            writeln("Error: SDL library is not found. Please, install SDL 2.0.14");
            return;
        }
    }
    
    if (SDL_Init(SDL_INIT_EVERYTHING) == -1)
    {
        writeln("Error: failed to init SDL: ", to!string(SDL_GetError()));
        return;
    }
    
    enum videoWidth = 1024;
    enum videoHeight = 768;

    enum realWidth = 320;
    enum realHeight = 240;
    mglInit(realWidth, realHeight);

    uint fbScaled = mglAddFrameBuffer();
    mglBindFrameBuffer(fbScaled);
    mglSetFrameBuffer(videoWidth, videoHeight);
    mglBindFrameBuffer(0);
    
    SDL_Window* window = SDL_CreateWindow(toStringz("MiniGL Demo"),
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        videoWidth, videoHeight,
        SDL_WINDOW_SHOWN);
    if (window is null)
    {
        writeln("Error: failed to create window: ", to!string(SDL_GetError()));
        return;
    }
    SDL_Surface* s = SDL_GetWindowSurface(window);
    
    Timer timer;

    mglBindFrameBuffer(fbScaled);
    SDL_Surface* buf = SDL_CreateRGBSurfaceFrom(
        mglColorBufferAdr(), videoWidth, videoHeight, 32, videoWidth*4, 
        0x000000FF, 0x0000FF00, 0x00FF0000, 0);
    mglBindFrameBuffer(0);
    
    Vector3f camPos = Vector3f(0, -0.5, 0);
    float camTurn = degtorad(-90.0f);
    Matrix4x4f cameraMatrix = Matrix4x4f.identity;

    float aspect = cast(float)(realWidth)/cast(float)(realHeight);
    auto projectionMatrix = perspectiveMatrix(80.0f, aspect, 0.01f, 10.0f);
    mglSetProjectionMatrix(projectionMatrix.arrayof.ptr);

    float[] vertsWall = [
        0.5,  0, 0,
        0.5, -1, 0,
       -0.5, -1, 0,
       -0.5,  0, 0
    ];
    float[] texsWall = [
        1, 1,
        1, 0,
        0, 0,
        0, 1
    ];
    uint[] indicesWall = [
        0, 1, 2,
        3, 0, 2
    ];
    uint vbWall = mglAddVertexBuffer();
    mglBindVertexBuffer(vbWall);
    mglSetVertexBufferPositions(vertsWall.ptr, 3, cast(uint)(vertsWall.length / 3));
    mglSetVertexBufferTexcoords(texsWall.ptr, 2, cast(uint)(texsWall.length / 2));
    mglSetVertexBufferIndices(indicesWall.ptr, cast(uint)(indicesWall.length / 3));
    mglBindVertexBuffer(0);

    float[] vertsFloor = [
       -0.5,  0, -0.5,
        0.5,  0, -0.5,
        0.5,  0,  0.5,
       -0.5,  0,  0.5
    ];
    float[] texsFloor = [
        0, 0,
        1, 0,
        1, 1,
        0, 1
    ];
    uint[] indicesFloor = [
        0, 1, 2,
        0, 2, 3
    ];
    uint vbFloor = mglAddVertexBuffer();
    mglBindVertexBuffer(vbFloor);
    mglSetVertexBufferPositions(vertsFloor.ptr, 3, cast(uint)(vertsFloor.length / 3));
    mglSetVertexBufferTexcoords(texsFloor.ptr, 2, cast(uint)(texsFloor.length / 2));
    mglSetVertexBufferIndices(indicesFloor.ptr, cast(uint)(indicesFloor.length / 3));
    mglBindVertexBuffer(0);

    auto img0 = loadPNG("textures/wall.png");
    uint texWall = mglAddTexture();
    mglBindTexture(texWall);
    mglSetTexture(img0.data.ptr, img0.width, img0.height, img0.channels);
    mglBindTexture(0);

    auto img1 = loadPNG("textures/floor.png");
    uint texFloor = mglAddTexture();
    mglBindTexture(texFloor);
    mglSetTexture(img1.data.ptr, img1.width, img1.height, img1.channels);
    mglBindTexture(0);

    auto img2 = loadPNG("textures/ceiling.png");
    uint texCeiling = mglAddTexture();
    mglBindTexture(texCeiling);
    mglSetTexture(img2.data.ptr, img2.width, img2.height, img2.channels);
    mglBindTexture(0);

    mglSetClipPlanes(0.1f, 4.0f);
    mglEnable(MGL_TEXTURE);
    //mglEnable(MGL_BILINEAR_FILTER); // Warning! Can be slow
    mglDisable(MGL_BLEND);
    mglEnable(MGL_FOG);
    mglSetFogDistance(0.0f, 4.0f);
    mglSetFogColor(0.2f, 0.1f, 0.2f, 1.0f);

    LevelSegment[] floors = [
        LevelSegment( 0, 0, 0, texFloor),
        LevelSegment( 1, 0, 0, texFloor),
        LevelSegment(-1, 0, 0, texFloor),

        LevelSegment( 0, 0, 1, texFloor),
        LevelSegment( 1, 0, 1, texFloor),
        LevelSegment(-1, 0, 1, texFloor),

        LevelSegment( 0, 0, 2, texFloor),
        LevelSegment( 1, 0, 2, texFloor),
        LevelSegment(-1, 0, 2, texFloor),

        LevelSegment( 2, 0, 1, texFloor),
        LevelSegment( 3, 0, 1, texFloor),
        LevelSegment( 4, 0, 1, texFloor),
        
        LevelSegment( -2, 0, 1, texFloor),
        LevelSegment( -3, 0, 1, texFloor),
        LevelSegment( -4, 0, 1, texFloor),
    ];

    LevelSegment[] walls = [
        LevelSegment( 0, 0, 2.5, texWall, 0),
        LevelSegment( 1, 0, 2.5, texWall, 0),
        LevelSegment(-1, 0, 2.5, texWall, 0),

        LevelSegment( 0, 0, -0.5, texWall, 0),
        LevelSegment( 1, 0, -0.5, texWall, 0),
        LevelSegment(-1, 0, -0.5, texWall, 0),

        LevelSegment( -1.5, 0, 0, texWall, 90),
        LevelSegment( -1.5, 0, 2, texWall, 90),

        LevelSegment(  1.5, 0, 0, texWall, 90),
        LevelSegment(  1.5, 0, 2, texWall, 90),

        LevelSegment(  2.0, 0,  1.5, texWall, 0),
        LevelSegment(  2.0, 0,  0.5, texWall, 0),
        LevelSegment(  3.0, 0,  1.5, texWall, 0),
        LevelSegment(  3.0, 0,  0.5, texWall, 0),
        LevelSegment(  4.0, 0,  1.5, texWall, 0),
        LevelSegment(  4.0, 0,  0.5, texWall, 0),
        
        LevelSegment( -2.0, 0,  1.5, texWall, 0),
        LevelSegment( -2.0, 0,  0.5, texWall, 0),
        LevelSegment( -3.0, 0,  1.5, texWall, 0),
        LevelSegment( -3.0, 0,  0.5, texWall, 0),
        LevelSegment( -4.0, 0,  1.5, texWall, 0),
        LevelSegment( -4.0, 0,  0.5, texWall, 0)
    ];

    LevelSegment[] ceilings = [
        LevelSegment( 0, -1, 0, texCeiling),
        LevelSegment( 1, -1, 0, texCeiling),
        LevelSegment(-1, -1, 0, texCeiling),

        LevelSegment( 0, -1, 1, texCeiling),
        LevelSegment( 1, -1, 1, texCeiling),
        LevelSegment(-1, -1, 1, texCeiling),

        LevelSegment( 0, -1, 2, texCeiling),
        LevelSegment( 1, -1, 2, texCeiling),
        LevelSegment(-1, -1, 2, texCeiling),

        LevelSegment( 2, -1, 1, texCeiling),
        LevelSegment( 3, -1, 1, texCeiling),
        LevelSegment( 4, -1, 1, texCeiling),
        
        LevelSegment(-2, -1, 1, texCeiling),
        LevelSegment(-3, -1, 1, texCeiling),
        LevelSegment(-4, -1, 1, texCeiling)
    ];
    
    int mouseX = 0;
    int mouseY = 0;
    float mouseSensibility = 0.1f;
    float pitchLimitMax = 60.0f;
    float pitchLimitMin = -60.0f;
    
    SDL_WarpMouseInWindow(window, videoWidth/2, videoHeight/2);
    int prevMouseX = videoWidth/2;
    int prevMouseY = videoHeight/2;
    
    float pitch = 0.0f;
    float turn = 0.0f;
    Quaternionf baseOrientation = Quaternionf.identity;
    
    float t = 0.0f;
    float time = 0.0f;
    
    bool[512] keyPressed = false;
    SDL_Event e;
    bool running = true;
    while(running)
    {
        timer.update();
        while(SDL_PollEvent(&e))
        {
            if (e.type == SDL_QUIT)
            {
                running = false;
            }
            else if (e.type == SDL_KEYDOWN)
            {
                keyPressed[e.key.keysym.scancode] = true;
            }
            else if (e.type == SDL_KEYUP)
            {
                keyPressed[e.key.keysym.scancode] = false;
            }
            else if (e.type == SDL_MOUSEMOTION)
            {
                mouseX = e.motion.x;
                mouseY = e.motion.y;
            }
        }
        
        if (keyPressed[KEY_RETURN]) {
            SDL_SaveBMP(buf, "frame.bmp");
        }
        if (keyPressed[KEY_ESCAPE]) {
            running = false;
        }
        
        float mouseRelH = (mouseX - prevMouseX) * mouseSensibility;
        float mouseRelV = (mouseY - prevMouseY) * mouseSensibility;
        pitch += mouseRelV;
        turn -= mouseRelH;
        if (pitch > pitchLimitMax)
            pitch = pitchLimitMax;
        else if (pitch < pitchLimitMin)
            pitch = pitchLimitMin;
        SDL_WarpMouseInWindow(window, videoWidth/2, videoHeight/2);
        prevMouseX = videoWidth/2;
        prevMouseY = videoHeight/2;
        
        auto rotPitch = rotationQuaternion(Vector3f(1.0f, 0.0f, 0.0f), degtorad(pitch));
        auto rotTurn = rotationQuaternion(Vector3f(0.0f, 1.0f, 0.0f), degtorad(turn));
        Quaternionf cameraOrientation = baseOrientation * rotTurn * rotPitch;
        auto turnMatrix = rotTurn.toMatrix4x4;
        
        cameraMatrix =
            translationMatrix(camPos) * 
            cameraOrientation.toMatrix4x4;
        auto mv = cameraMatrix.inverse;
        
        if (keyPressed[KEY_W]) camPos += -turnMatrix.forward  * 2.0f * timer.deltaTime;
        if (keyPressed[KEY_S]) camPos += turnMatrix.forward * 2.0f * timer.deltaTime;
        if (keyPressed[KEY_A]) camPos += -turnMatrix.right  * 2.0f * timer.deltaTime;
        if (keyPressed[KEY_D]) camPos += turnMatrix.right  * 2.0f * timer.deltaTime;
        
        mglClearColor(0.2f, 0.1f, 0.2f, 1.0);
        mglClearDepth(1.0);
        
        mglSetModelViewMatrix(mv.arrayof.ptr);
        
        time += timer.deltaTime;
        if (time >= 2.0f * PI) time = 0.0f;
        t = (sin(time * 4.0f) + 1.0f) * 0.5f;
        mglSetShaderParameter1f(0, t);
        
        foreach(ref f; floors)
        {
            auto mvPrev = mv;
            mv *= translationMatrix(Vector3f(f.x, f.y, f.z));
            mglSetModelViewMatrix(mv.arrayof.ptr);
            mglBindTexture(f.textureId);
            mglBindVertexBuffer(vbFloor);
            mglBindPixelShader(&psRed);
            mglDrawVertexBuffer();
            mglBindPixelShader(null);
            mglBindVertexBuffer(0);
            mglBindTexture(0);
            mv = mvPrev;
        }
        
        foreach(ref c; ceilings)
        {
            auto mvPrev = mv;
            mv *= translationMatrix(Vector3f(c.x, c.y, c.z));
            mglSetModelViewMatrix(mv.arrayof.ptr);
            mglBindTexture(c.textureId);
            mglBindVertexBuffer(vbFloor);
            mglDrawVertexBuffer();
            mglBindVertexBuffer(0);
            mglBindTexture(0);
            mv = mvPrev;
        }
        
        foreach(ref w; walls)
        {
            auto mvPrev = mv;
            mv *= translationMatrix(Vector3f(w.x, w.y, w.z));
            mv *= rotationMatrix(1, degtorad(w.angle));
            mglSetModelViewMatrix(mv.arrayof.ptr);
            mglBindTexture(w.textureId);
            mglBindVertexBuffer(vbWall);
            mglDrawVertexBuffer();
            mglBindVertexBuffer(0);
            mglBindTexture(0);
            mv = mvPrev;
        }
        
        mglBlitFrameBuffer(fbScaled, 0);
        
        SDL_BlitSurface(buf, null, s, null);
        SDL_UpdateWindowSurface(window);
    }
    
    SDL_FreeSurface(buf);

    mglRelease();
    
    SDL_Quit();
}
