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
module minigl;

import std.math;
import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.interpolation;
import dlib.container.array;
import dlib.image.color;

private:

struct MGLFrameBuffer
{
    uint width;
    uint height;
    ubyte[] colorbuf;
    float[] depthbuf;
}

struct MGLVertexBuffer
{
    Vector4f[] vertexbuf;
    Vector4f[] texcoordbuf;
    uint[3][] indexbuf;
}

struct MGLTriangle
{
    Vector4f[3] pos;
    Vector4f[3] texcoord;
}

struct MGLTexture
{
    uint width;
    uint height;
    uint numChannels;
    ubyte[] buffer;
}

Vector3f viewportCoord(Vector3f ndc, int width, int height, float znear, float zfar)
{
    Vector3f v;
    float depth = (zfar - znear);
    v.x = (ndc.x * 0.5f + 0.5f) * (cast(float)width);
    v.y = (ndc.y * 0.5f + 0.5f) * (cast(float)height);
    v.z = ndc.z / 100.0f;
    return v;
}

float clampf(float v, float mi, float ma)
{
    if (v < mi) return mi;
    else if (v > ma) return ma;
    else return v; 
}

Vector3f clampVector3f(Vector3f v, float mi, float ma)
{
    return Vector3f(
        clampf(v.x, mi, ma),
        clampf(v.y, mi, ma),
        clampf(v.z, mi, ma));
}

T min2(T)(T a, T b)
{
    return (a < b)? a : b;
}

T max2(T)(T a, T b)
{
    return (a > b)? a : b;
}

Vector3f barycentric(Vector3f[3] pts, Vector3f P)
{ 
    Vector3f u = cross(
        Vector3f(pts[2][0]-pts[0][0], pts[1][0]-pts[0][0], pts[0][0]-P[0]),
        Vector3f(pts[2][1]-pts[0][1], pts[1][1]-pts[0][1], pts[0][1]-P[1]));
    if (abs(u[2])<1)
        return Vector3f(-1, 1, 1);
    return Vector3f(1.0f-(u.x+u.y)/u.z, u.y/u.z, u.x/u.z); 
} 

void fbSetPixColor(MGLFrameBuffer* fb, int x, int y, Color4f p)
{
    if (x >= 0 && y >= 0 && x < fb.width && y < fb.height)
    {
        ubyte* fptr = cast(ubyte*)(fb.colorbuf.ptr + (y * fb.width + x) * 4);
        enum m = (2 ^^ 8) - 1;
        ubyte r = cast(ubyte)(p.r * m);
        ubyte g = cast(ubyte)(p.g * m);
        ubyte b = cast(ubyte)(p.b * m);
        ubyte a = cast(ubyte)(p.a * m);
        fptr[0] = r;
        fptr[1] = g;
        fptr[2] = b;
        fptr[3] = 255;
    }
}

void fbAlphaPixColor(MGLFrameBuffer* fb, int x, int y, Color4f p)
{
    if (x >= 0 && y >= 0 && x < fb.width && y < fb.height)
    {
        ubyte* fptr = cast(ubyte*)(fb.colorbuf.ptr + (y * fb.width + x) * 4);
        enum m = (2 ^^ 8) - 1;
        ubyte r = cast(ubyte)(p.r * m);
        ubyte g = cast(ubyte)(p.g * m);
        ubyte b = cast(ubyte)(p.b * m);
        ubyte a = cast(ubyte)(p.a * m);
        ubyte oneMinusAlpha = 255 - a;
        fptr[0] = cast(ubyte)((a * r + oneMinusAlpha * fptr[0]) >> 8);
        fptr[1] = cast(ubyte)((a * g + oneMinusAlpha * fptr[1]) >> 8);
        fptr[2] = cast(ubyte)((a * b + oneMinusAlpha * fptr[2]) >> 8);
        fptr[3] = 255; //cast(ubyte)((a * a + oneMinusAlpha * fptr[3]) >> 8);
    }
}

void fbAddPixColor(MGLFrameBuffer* fb, int x, int y, Color4f p)
{
    if (x >= 0 && y >= 0 && x < fb.width && y < fb.height)
    {
        ubyte* fptr = cast(ubyte*)(fb.colorbuf.ptr + (y * fb.width + x) * 4);
        enum m = (2 ^^ 8) - 1;
        uint r = cast(uint)(p.r * m);
        uint g = cast(uint)(p.g * m);
        uint b = cast(uint)(p.b * m);
        uint a = cast(uint)(p.a * m);
        fptr[0] = cast(ubyte)min2(r + fptr[0], 255);
        fptr[1] = cast(ubyte)min2(g + fptr[1], 255);
        fptr[2] = cast(ubyte)min2(b + fptr[2], 255);
        fptr[3] = 255; //cast(ubyte)((a + fptr[3]) >> 8);
    }
}

void fbModulatePixColor(MGLFrameBuffer* fb, int x, int y, Color4f p)
{
    if (x >= 0 && y >= 0 && x < fb.width && y < fb.height)
    {
        ubyte* fptr = cast(ubyte*)(fb.colorbuf.ptr + (y * fb.width + x) * 4);
        enum m = (2 ^^ 8) - 1;
        uint r = cast(uint)(p.r * m);
        uint g = cast(uint)(p.g * m);
        uint b = cast(uint)(p.b * m);
        uint a = cast(uint)(p.a * m);
        fptr[0] = cast(ubyte)((r * fptr[0]) >> 8);
        fptr[1] = cast(ubyte)((g * fptr[1]) >> 8);
        fptr[2] = cast(ubyte)((b * fptr[2]) >> 8);
        fptr[3] = 255; //cast(ubyte)((a + fptr[3]) >> 8);
    }
}

void fbSetPixelDepth(MGLFrameBuffer* fb, int x, int y, float z)
{
    if (x >= 0 && y >= 0 && x < fb.width && y < fb.height)
        fb.depthbuf.ptr[y * fb.width + x] = z;
}

float fbGetPixelDepth(MGLFrameBuffer* fb, int x, int y)
{
    if (x >= 0 && y >= 0 && x < fb.width && y < fb.height)
        return fb.depthbuf.ptr[y * fb.width + x];
    else
        return 1.0f;
}

void fbClearColor(MGLFrameBuffer* fb, Color4f col)
{
    enum m = (2 ^^ 8) - 1;
    ubyte r = cast(ubyte)(col.r * m);
    ubyte g = cast(ubyte)(col.g * m);
    ubyte b = cast(ubyte)(col.b * m);
    ubyte a = cast(ubyte)(col.a * m);

    for (size_t i = 0; i < fb.colorbuf.length; i+=4)
    {
        fb.colorbuf.ptr[i] = r;
        fb.colorbuf.ptr[i+1] = g;
        fb.colorbuf.ptr[i+2] = b;
        fb.colorbuf.ptr[i+3] = a;
    }
}

void fbClearDepth(MGLFrameBuffer* fb, float v)
{
    for (size_t i = 0; i < fb.depthbuf.length; i++)
        fb.depthbuf.ptr[i] = v;
}

void fbBlitColor(MGLFrameBuffer* fb1, MGLFrameBuffer* fb2)
{
    float scaleWidth  = cast(float)fb1.width / cast(float)fb2.width;
    float scaleHeight = cast(float)fb1.height / cast(float)fb2.height;

    uint nearest_x, nearest_y;

    for(uint y = 0; y < fb1.height; y++)
    for(uint x = 0; x < fb1.width; x++)
    {
        nearest_x = cast(uint)(x / scaleWidth);
        nearest_y = cast(uint)(y / scaleHeight);

        ubyte* p = cast(ubyte*)(fb2.colorbuf.ptr + (nearest_y * fb2.width + nearest_x) * 4);
        size_t offset = (y * fb1.width + x) * 4;
        fb1.colorbuf.ptr[offset] = *p;
        fb1.colorbuf.ptr[offset+1] = *(p+1);
        fb1.colorbuf.ptr[offset+2] = *(p+2);
        fb1.colorbuf.ptr[offset+3] = *(p+3);
    }
}

Color4f texSample(const(MGLTexture)* tex, Vector2f uv)
{
    Color4f res = Color4f(1, 1, 1, 1);

    if (!tex.buffer.length)
        return res;

    int x = cast(int)(uv.x * tex.width) % tex.width;
    int y = cast(int)(uv.y * tex.height) % tex.height;
    if (x < 0) x += tex.width;
    if (y < 0) y += tex.height;

    ubyte* tptr = cast(ubyte*)(tex.buffer.ptr + (y * tex.width + x) * tex.numChannels);
    enum float m = 1.0f / 255.0f;
    res.r = cast(float)tptr[0] * m;
    res.g = cast(float)tptr[1] * m;
    res.b = cast(float)tptr[2] * m;
    res.a = cast(float)tptr[3] * m;
    return res;
}

Color4f texSampleBilinear(const(MGLTexture)* tex, Vector2f uv)
{
    Color4f res = Color4f(1, 1, 1, 1);

    if (!tex.buffer.length)
        return res;

    enum int shift = 8;
    int widthSH = (tex.width<<shift);
    int heightSH = (tex.height<<shift);
    
    int u = cast(int)(uv.x * widthSH) % widthSH;
    int v = cast(int)(uv.y * heightSH) % heightSH;

    if (u < 0) u += widthSH;
    if (v < 0) v += heightSH;
    
    int u0 = u >> shift;
    int v0 = v >> shift;
    int u1 = (u0 + 1) % tex.width;
    int v1 = (v0 + 1) % tex.height;
    
    const(ubyte)* c00 = (tex.buffer.ptr + (u0 + tex.width * v0) * tex.numChannels);
    const(ubyte)* c10 = (tex.buffer.ptr + (u1 + tex.width * v0) * tex.numChannels);
    const(ubyte)* c01 = (tex.buffer.ptr + (u0 + tex.width * v1) * tex.numChannels);
    const(ubyte)* c11 = (tex.buffer.ptr + (u1 + tex.width * v1) * tex.numChannels);
    
    int uoff = u & ((1 << shift) - 1);
    int voff = v & ((1 << shift) - 1);

    uint r = (((c00[0] * ((1 << shift) - uoff) + uoff * c10[0])) * ((1 << shift) - voff)
            + ((c01[0] * ((1 << shift) - uoff) + uoff * c11[0])) * voff) >> shift*2;

    uint g = (((c00[1] * ((1 << shift) - uoff) + uoff * c10[1])) * ((1 << shift) - voff)
            + ((c01[1] * ((1 << shift) - uoff) + uoff * c11[1])) * voff) >> shift*2;

    uint b = (((c00[2] * ((1 << shift) - uoff) + uoff * c10[2])) * ((1 << shift) - voff)            + ((c01[2] * ((1 << shift) - uoff) + uoff * c11[2])) * voff) >> shift*2;

    enum float m = 1.0f / 255.0f;
    if (tex.numChannels == 4)
    {
        uint a = (((c00[3] * ((1 << shift) - uoff) + uoff * c10[3])) * ((1 << shift) - voff)                + ((c01[3] * ((1 << shift) - uoff) + uoff * c11[3])) * voff) >> shift*2;

        res.a = cast(float)a * m;
        res.r = cast(float)r * m;
        res.g = cast(float)g * m;
        res.b = cast(float)b * m;
    }
    else
    {
        res.a = 1.0f;
        res.r = cast(float)r * m;
        res.g = cast(float)g * m;
        res.b = cast(float)b * m;
    }

    return res;
}

struct VSOutput
{
    Vector4f position;
    Vector2f texcoord;
}

struct PSOutput
{
    Color4f color;
}

alias VertexShaderFunc = VSOutput function(const ref MGLState state, Vector4f coords, Vector2f uv);
alias PixelShaderFunc = PSOutput function(const ref MGLState state, Vector4f coords, Vector2f uv);

VSOutput defaultVertexShaderFunc(const ref MGLState state, Vector4f coords, Vector2f uv)
{
    Vector4f pos = coords * state.mvpMatrix;
    Vector2f texcoord = uv;
    return VSOutput(pos, texcoord);
}

PSOutput defaultPixelShaderFunc(const ref MGLState state, Vector4f coords, Vector2f uv)
{
    Color4f pixColor;
    if (state.options[MGL_TEXTURE] && state.texture[0])
    {
        if (state.options[MGL_BILINEAR_FILTER])
            pixColor = texSampleBilinear(state.texture[0], uv) * state.color;
        else
            pixColor = texSample(state.texture[0], uv) * state.color;
    }
    else
        pixColor = state.color;
    
    if (state.options[MGL_FOG])
    {
        float alpha = pixColor.a;
        float fogDistance = coords.w;
        float fogFactor = clampf((state.fogEnd - fogDistance) / (state.fogEnd - state.fogStart), 0.0f, 1.0f);
        Color4f fogColor = state.fogColor;
        pixColor = lerp(fogColor, pixColor, fogFactor);
        pixColor.a = alpha;
    }
    
    return PSOutput(pixColor);
}

struct MGLState
{
    Array!MGLFrameBuffer framebuffers;
    MGLFrameBuffer* fbCurrent;

    Array!MGLVertexBuffer vertexbuffers;
    MGLVertexBuffer* vbCurrent;

    Array!MGLTexture textures;
    MGLTexture*[32] texture;

    Matrix4x4f mvMatrix;
    Matrix4x4f projMatrix;
    Matrix4x4f mvpMatrix;

    Color4f color = Color4f(1.0f, 1.0f, 1.0f, 1.0f);

    bool[10] options;
    uint blendMode = MGL_BLEND_ALPHA;

    float znear = 0.1f;
    float zfar = 100.0f;

    float fogStart = 0.0f;
    float fogEnd = 1.0f;
    Color4f fogColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
    
    VertexShaderFunc vertexShaderFunc;
    PixelShaderFunc pixelShaderFunc;
    
    Vector4f[32] shaderParameters;
    
    Color4f textureSample(const(MGLTexture)* tex, Vector2f uv) const
    {
        return options[MGL_BILINEAR_FILTER]?
            texSampleBilinear(tex, uv) :
            texSample(tex, uv);
    }

    void release()
    {
        foreach(fb; framebuffers)
        {
            if (fb.colorbuf.length)
                Delete(fb.colorbuf);
            if (fb.depthbuf.length)
                Delete(fb.depthbuf);
        }
        framebuffers.free();

        foreach(vb; vertexbuffers)
        {
            if (vb.vertexbuf.length)
                Delete(vb.vertexbuf);
            if (vb.texcoordbuf.length)
                Delete(vb.texcoordbuf);
        }
        vertexbuffers.free();

        foreach(tex; textures)
        {
            if (tex.buffer.length)
                Delete(tex.buffer);
        }
        textures.free();
    }

    this(uint frameWidth, uint frameHeight)
    {
        MGLFrameBuffer fbMain;
        fbMain.width = frameWidth;
        fbMain.height = frameHeight;
        fbMain.colorbuf = New!(ubyte[])(fbMain.width * fbMain.height * 4);
        fbMain.depthbuf = New!(float[])(fbMain.width * fbMain.height);
        framebuffers.append(fbMain);
        fbCurrent = &framebuffers.data[0];

        mvMatrix = Matrix4x4f.identity;
        projMatrix = Matrix4x4f.identity;
        mvpMatrix = Matrix4x4f.identity;

        color = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        
        options[MGL_TEXTURE] = false;
        options[MGL_BLEND] = false;
        options[MGL_BILINEAR_FILTER] = false;
        options[MGL_FOG] = false;
        options[MGL_DEPTH_TEST] = true;
        options[MGL_DEPTH_WRITE] = true;
        
        vertexShaderFunc = &defaultVertexShaderFunc;
        pixelShaderFunc = &defaultPixelShaderFunc;
    }

    uint addFrameBuffer()
    {
        MGLFrameBuffer fb;
        framebuffers.append(fb);
        return cast(uint)framebuffers.length;
    }

    void bindFrameBuffer(uint fb)
    {
        if (fb == 0)
        {
            fbCurrent = &framebuffers.data[0];
        }
        else if (fb <= framebuffers.length)
            fbCurrent = &framebuffers.data[fb-1];
    }

    void setFrameBuffer(uint width, uint height)
    {
        if (!fbCurrent)
            return;

        if (fbCurrent.colorbuf.length)
            Delete(fbCurrent.colorbuf);
        if (fbCurrent.depthbuf.length)
            Delete(fbCurrent.depthbuf);

        fbCurrent.width = width;
        fbCurrent.height = height;
        fbCurrent.colorbuf = New!(ubyte[])(fbCurrent.width * fbCurrent.height * 4);
        fbCurrent.depthbuf = New!(float[])(fbCurrent.width * fbCurrent.height);
    }

    void blitFrameBuffer(uint fb1, uint fb2)
    {
        MGLFrameBuffer* pfb1;
        MGLFrameBuffer* pfb2;

        if (fb1 == 0)
        {
            pfb1 = &framebuffers.data[0];
        }
        else if (fb1 <= framebuffers.length)
            pfb1 = &framebuffers.data[fb1-1];

        if (fb2 == 0)
        {
            pfb2 = &framebuffers.data[0];
        }
        else if (fb2 <= framebuffers.length)
            pfb2 = &framebuffers.data[fb2-1];

        if (!pfb1.colorbuf.length || !pfb2.colorbuf.length)
            return;

        fbBlitColor(pfb1, pfb2);
    }

    uint addVertexBuffer()
    {
        MGLVertexBuffer vb;
        vertexbuffers.append(vb);
        return cast(uint)vertexbuffers.length;
    }

    void bindVertexBuffer(uint vb)
    {
        if (vb == 0)
        {
            vbCurrent = null;
        }
        else if (vb <= vertexbuffers.length)
            vbCurrent = &vertexbuffers.data[vb-1];
    }

    void setVertexBufferPositions(float* adr, uint numElements, uint len)
    {
        if (!vbCurrent)
            return;

        if (vbCurrent.vertexbuf.length)
            Delete(vbCurrent.vertexbuf);

        vbCurrent.vertexbuf = New!(Vector4f[])(len);
        for (uint i = 0; i < vbCurrent.vertexbuf.length; i++)
        {
            vbCurrent.vertexbuf[i] = Vector4f(0, 0, 0, 1);

            for (uint j = 0; j < numElements; j++)
                if (j < 4)
                    vbCurrent.vertexbuf[i].arrayof[j] = adr[i * numElements + j];
        }
    }

    void setVertexBufferTexcoords(float* adr, uint numElements, uint len)
    {
        if (!vbCurrent)
            return;

        if (vbCurrent.texcoordbuf.length)
            Delete(vbCurrent.texcoordbuf);

        vbCurrent.texcoordbuf = New!(Vector4f[])(len);
        for (uint i = 0; i < vbCurrent.texcoordbuf.length; i++)
        {
            vbCurrent.texcoordbuf[i] = Vector4f(0, 0, 0, 1);

            for (uint j = 0; j < numElements; j++)
                if (j < 4)
                    vbCurrent.texcoordbuf[i].arrayof[j] = adr[i * numElements + j];
        }
    }

    void setVertexBufferIndices(uint* adr, uint len)
    {
        if (!vbCurrent)
            return;

        if (vbCurrent.indexbuf.length)
            Delete(vbCurrent.indexbuf);

        vbCurrent.indexbuf = New!(uint[3][])(len);

        for (uint i = 0; i < vbCurrent.indexbuf.length; i++)
        {
            vbCurrent.indexbuf[i][0] = adr[i*3];
            vbCurrent.indexbuf[i][1] = adr[i*3+1];
            vbCurrent.indexbuf[i][2] = adr[i*3+2];
        }
    }

    void drawVertexBuffer()
    {
        if (!vbCurrent)
            return;

        MGLTriangle tri;

        if (!vbCurrent.vertexbuf.length)
            return;
        
        mvpMatrix = projMatrix * mvMatrix;

        foreach(index; vbCurrent.indexbuf)
        {
            if (vbCurrent.texcoordbuf.length)
            {
                tri.texcoord[0] = vbCurrent.texcoordbuf[index[0]];
                tri.texcoord[1] = vbCurrent.texcoordbuf[index[1]];
                tri.texcoord[2] = vbCurrent.texcoordbuf[index[2]];
            }
            else
            {
                tri.texcoord[0] = Vector4f(0, 0, 0, 0);
                tri.texcoord[1] = Vector4f(0, 0, 0, 0);
                tri.texcoord[2] = Vector4f(0, 0, 0, 0);
            }

            tri.pos[0] = vbCurrent.vertexbuf[index[0]];
            tri.pos[1] = vbCurrent.vertexbuf[index[1]];
            tri.pos[2] = vbCurrent.vertexbuf[index[2]];

            drawTriangle(&tri);
        }
    }

    uint addTexture()
    {
        MGLTexture tex;
        textures.append(tex);
        return cast(uint)textures.length;
    }

    void bindTexture(uint unit, uint tex)
    {
        if (tex == 0)
        {
            texture[unit] = null;
        }
        else if (tex <= textures.length)
            texture[unit] = &textures.data[tex-1];
    }

    void setTextureData(uint tex, ubyte* data, uint width, uint height, uint numChannels)
    {
        MGLTexture* t = &textures.data[tex-1];
        
        if (!t)
            return;

        if (t.buffer.length)
            Delete(t.buffer);

        t.width = width;
        t.height = height;
        t.numChannels = numChannels;
        t.buffer = New!(ubyte[])(width * height * numChannels);

        for (uint i = 0; i < t.buffer.length; i++)
        {
            t.buffer[i] = data[i];
        }
    }

    void drawTriangle(MGLTriangle* tri)
    {
        VSOutput v1 = vertexShaderFunc(this, tri.pos[0], tri.texcoord[0].xy);
        VSOutput v2 = vertexShaderFunc(this, tri.pos[1], tri.texcoord[1].xy);
        VSOutput v3 = vertexShaderFunc(this, tri.pos[2], tri.texcoord[2].xy);
        Vector4f cs1 = v1.position;
        Vector4f cs2 = v2.position;
        Vector4f cs3 = v3.position;
        
        Vector2f[3] tcs;
        tcs[0] = v1.texcoord;
        tcs[1] = v2.texcoord;
        tcs[2] = v3.texcoord;

        Vector3f c1 = cs1.xyz;
        Vector3f c2 = cs2.xyz;
        Vector3f c3 = cs3.xyz;

        if (cs1.w < 0.005f) cs1.w = 0.005f;
        if (cs2.w < 0.005f) cs2.w = 0.005f;
        if (cs3.w < 0.005f) cs3.w = 0.005f;

        Vector3f ndc1 = c1 / cs1.w;
        Vector3f ndc2 = c2 / cs2.w;
        Vector3f ndc3 = c3 / cs3.w;

        Vector3f vc1 = viewportCoord(ndc1, fbCurrent.width, fbCurrent.height, znear, zfar);
        Vector3f vc2 = viewportCoord(ndc2, fbCurrent.width, fbCurrent.height, znear, zfar);
        Vector3f vc3 = viewportCoord(ndc3, fbCurrent.width, fbCurrent.height, znear, zfar);

        // Rounding, to eliminate gaps between edges
        Vector3f[3] pts;
        pts[0] = Vector3f(floor(vc1.x), floor(vc1.y), vc1.z);
        pts[1] = Vector3f(floor(vc2.x), floor(vc2.y), vc2.z);
        pts[2] = Vector3f(floor(vc3.x), floor(vc3.y), vc3.z);

        float[3] clipw;
        clipw[0] = cs1.w;
        clipw[1] = cs2.w;
        clipw[2] = cs3.w;
 
        Vector2f bboxmin = Vector2f(fbCurrent.width-1, fbCurrent.height-1);
        Vector2f bboxmax = Vector2f(0, 0);
        Vector2f clamped = Vector2f(fbCurrent.width-1, fbCurrent.height-1);
        for (int i=0; i<3; i++) 
        for (int j=0; j<2; j++)
        { 
            bboxmin[j] = max2(0,          min2(bboxmin[j], pts[i][j]));
            bboxmax[j] = min2(clamped[j], max2(bboxmax[j], pts[i][j]));
        } 

        float px, py, pz, pw;
        float u, v;

        float[3] invW;
        invW[0] = 1.0f / clipw[0];
        invW[1] = 1.0f / clipw[1];
        invW[2] = 1.0f / clipw[2];

        float iw;

        tcs[0] /= clipw[0];
        tcs[1] /= clipw[1];
        tcs[2] /= clipw[2];
    
        for (px = bboxmin.x; px <= bboxmax.x; px++)
        for (py = bboxmin.y; py <= bboxmax.y; py++)
        {
            Vector3f bc = barycentric(pts, Vector3f(px, py, pz));
            if (bc.x < 0 || bc.y < 0 || bc.z < 0)
                continue;

            uint xcoord = cast(uint)(ceil(px));
            uint ycoord = cast(uint)(ceil(py));

            pz = 0.0f;
            u = 0.0f;
            v = 0.0f;
            iw = 0.0f;
            for (uint i = 0; i < 3; i++)
            {
                pz += pts[i][2] * bc[i];
                u += tcs[i][0] * bc[i];
                v += tcs[i][1] * bc[i];
                iw += invW[i] * bc[i];
            }

            iw = 1.0f / iw;

            u *= iw;
            v *= iw;

            if (!options[MGL_DEPTH_TEST] || (pz < fbGetPixelDepth(fbCurrent, xcoord, ycoord) && pz > 0.0f && iw > znear && iw < zfar))
            {
                PSOutput fragment = pixelShaderFunc(this, Vector4f(px, py, pz, iw), Vector2f(u, v));
                Color4f pixColor = fragment.color;
                
                if (options[MGL_BLEND])
                {
                    if (blendMode == MGL_BLEND_ALPHA)
                        fbAlphaPixColor(fbCurrent, xcoord, ycoord, pixColor);
                    else if (blendMode == MGL_BLEND_ADDITIVE)
                        fbAddPixColor(fbCurrent, xcoord, ycoord, pixColor);
                    else if (blendMode == MGL_BLEND_MODULATE)
                        fbModulatePixColor(fbCurrent, xcoord, ycoord, pixColor);
                    else
                        fbSetPixColor(fbCurrent, xcoord, ycoord, pixColor);
                }
                else
                    fbSetPixColor(fbCurrent, xcoord, ycoord, pixColor);
                
                if (options[MGL_DEPTH_WRITE])
                    fbSetPixelDepth(fbCurrent, xcoord, ycoord, pz);
            }
        }
    } 
}

MGLState state;

public:

enum MGL_TEXTURE = 0;
enum MGL_BLEND = 1;
enum MGL_BILINEAR_FILTER = 2;
enum MGL_FOG = 3;
enum MGL_DEPTH_TEST = 4;
enum MGL_DEPTH_WRITE = 5;

enum MGL_BLEND_ALPHA = 0;
enum MGL_BLEND_ADDITIVE = 1;
enum MGL_BLEND_MODULATE = 2;

alias VSOut = VSOutput;
alias PSOut = PSOutput;
alias MGLPipelineState = MGLState;

alias VertexShaderEntry = VSOut function(const ref MGLPipelineState state, Vector4f coords, Vector2f uv);
alias PixelShaderEntry = PSOut function(const ref MGLPipelineState state, Vector4f coords, Vector2f uv);

void mglInit(uint fwidth, uint fheight)
{
    state.release();
    state = MGLState(fwidth, fheight);
}

void mglRelease()
{
    state.release();
}

ubyte* mglColorBufferAdr()
{
    return state.fbCurrent.colorbuf.ptr;
}

void mglEnable(uint option)
{
    state.options[option] = true;
}

void mglDisable(uint option)
{
    state.options[option] = false;
}

void mglSetBlendMode(uint bm)
{
    state.blendMode = bm;
}

void mglSetClipPlanes(float znear, float zfar)
{
    state.znear = znear;
    state.zfar = zfar;
}

void mglSetFogDistance(float start, float end)
{
    state.fogStart = start;
    state.fogEnd = end;
}

void mglSetFogColor(float r, float g, float b, float a)
{
    state.fogColor = Color4f(r, g, b, a);
}

void mglClearColor(float r, float g, float b, float a)
{
    fbClearColor(state.fbCurrent, Color4f(r, g, b, a));
}

void mglClearDepth(float z)
{
    fbClearDepth(state.fbCurrent, z);
}

void mglSetColor(float r, float g, float b, float a)
{
    state.color = Color4f(r, g, b, a);
}

void mglSetModelViewMatrix(float* m)
{
    for(uint i = 0; i < 16; i++)
        state.mvMatrix.arrayof[i] = m[i];
}

void mglSetProjectionMatrix(float* m)
{
    for(uint i = 0; i < 16; i++)
        state.projMatrix.arrayof[i] = m[i];
}

uint mglAddTexture()
{
    return state.addTexture();
}

void mglSetTextureData(uint tex, ubyte* data, uint width, uint height, uint numChannels)
{
    return state.setTextureData(tex, data, width, height, numChannels);
}

void mglBindTexture(uint unit, uint tex)
{
    state.bindTexture(unit, tex);
}

void mglBindVertexShader(VertexShaderEntry vsEntry)
{
    if (vsEntry is null)
        state.vertexShaderFunc = &defaultVertexShaderFunc;
    else
        state.vertexShaderFunc = vsEntry;
}

void mglBindPixelShader(PixelShaderEntry psEntry)
{
    if (psEntry is null)
        state.pixelShaderFunc = &defaultPixelShaderFunc;
    else
        state.pixelShaderFunc = psEntry;
}

void mglSetShaderParameter1f(uint index, float v)
{
    auto p = &state.shaderParameters[index];
    p.x = v;
}

void mglSetShaderParameter4f(uint index, const(float)* vecPtr)
{
    auto p = &state.shaderParameters[index];
    p.x = vecPtr[0];
    p.y = vecPtr[1];
    p.z = vecPtr[2];
    p.w = vecPtr[3];
}

uint mglAddVertexBuffer()
{
    return state.addVertexBuffer();
}

void mglBindVertexBuffer(uint vb)
{
    state.bindVertexBuffer(vb);
}

void mglSetVertexBufferPositions(float* adr, uint numElements, uint len)
{
    state.setVertexBufferPositions(adr, numElements, len);
}

void mglSetVertexBufferTexcoords(float* adr, uint numElements, uint len)
{
    state.setVertexBufferTexcoords(adr, numElements, len);
}

void mglSetVertexBufferIndices(uint* adr, uint len)
{
    state.setVertexBufferIndices(adr, len);
}

void mglDrawVertexBuffer()
{
    state.drawVertexBuffer();
}

uint mglAddFrameBuffer()
{
    return state.addFrameBuffer();
}

void mglBindFrameBuffer(uint fb)
{
    state.bindFrameBuffer(fb);
}

void mglSetFrameBuffer(uint width, uint height)
{
    state.setFrameBuffer(width, height);
}

void mglBlitFrameBuffer(uint fb1, uint fb2)
{
    state.blitFrameBuffer(fb1, fb2);
}
