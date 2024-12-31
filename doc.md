# MiniGL 1.0 Documentation

## mglInit
```d
void mglInit(uint fwidth, uint fheight)
```
Releases and recreates the state with given frame width and height. This function deletes all previously created frame buffers, vertex buffers and textures.

`fwidth`, `fheight` - width and height of a default (0) frame buffer. These should match the dimensions of 

## mglRelease
```d
void mglRelease()
```
Releases the state. This function deletes all previously created frame buffers, vertex buffers and textures.

## mglColorBufferAdr
```d
ubyte* mglColorBufferAdr()
```
Returns pointer to the beginning of a currently bound frame buffer's color data.

## mglEnable
```d
void mglEnable(uint option)
```
Enables a state option.

`option` - one of the predefined constants: `MGL_TEXTURE`, `MGL_BLEND`, `MGL_BILINEAR_FILTER`, `MGL_FOG`.

## mglDisable
```d
void mglDisable(uint option)
```
Disables a state option.

`option` - one of the predefined constants: `MGL_TEXTURE`, `MGL_BLEND`, `MGL_BILINEAR_FILTER`, `MGL_FOG`.

## mglSetBlendMode
```d
void mglSetBlendMode(uint bm)
```

## mglSetClipPlanes
```d
void mglSetClipPlanes(float znear, float zfar)
```

## mglSetFogDistance
```d
void mglSetFogDistance(float start, float end)
```

## mglSetFogColor
```d
void mglSetFogColor(float r, float g, float b, float a)
```

## mglClearColor
```d
void mglClearColor(float r, float g, float b, float a)
```

## mglClearDepth
```d
void mglClearDepth(float z)
```

## mglSetColor
```d
void mglSetColor(float r, float g, float b, float a)
```

## mglSetModelViewMatrix
```d
void mglSetModelViewMatrix(float* m)
```

## mglSetProjectionMatrix
```d
void mglSetProjectionMatrix(float* m)
```

## mglAddTexture
```d
uint mglAddTexture()
```

## mglSetTextureData
```d
void mglSetTextureData(uint tex, ubyte* data, uint width, uint height, uint numChannels)
```

## mglBindTexture
```d
void mglBindTexture(uint unit, uint tex)
```

## mglBindVertexShader
```d
void mglBindVertexShader(VertexShaderEntry vsEntry)
```

## mglBindPixelShader
```d
void mglBindPixelShader(PixelShaderEntry psEntry)
```

## mglSetShaderParameter1f
```d
void mglSetShaderParameter1f(uint index, float v)
```

## mglSetShaderParameter4f
```d
void mglSetShaderParameter4f(uint index, const(float)* vecPtr)
```

## mglAddVertexBuffer
```d
uint mglAddVertexBuffer()
```

## mglBindVertexBuffer
```d
void mglBindVertexBuffer(uint vb)
```

## mglSetVertexBufferPositions
```d
void mglSetVertexBufferPositions(float* adr, uint numElements, uint len)
```

## mglSetVertexBufferTexcoords
```d
void mglSetVertexBufferTexcoords(float* adr, uint numElements, uint len)
```

## mglSetVertexBufferIndices
```d
void mglSetVertexBufferIndices(uint* adr, uint len)
```

## mglDrawVertexBuffer
```d
void mglDrawVertexBuffer()
```

## mglAddFrameBuffer
```d
uint mglAddFrameBuffer()
```

## mglBindFrameBuffer
```d
void mglBindFrameBuffer(uint fb)
```

## mglSetFrameBuffer
```d
void mglSetFrameBuffer(uint width, uint height)
```

## mglBlitFrameBuffer
```d
void mglBlitFrameBuffer(uint fb1, uint fb2)
```
