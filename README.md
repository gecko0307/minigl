# MiniGL
Small (<1000 LoC) OpenGL-inspired old-school software rasterizer written in D language just for fun.

```d
mglClearColor(0.0f, 0.0f, 0.0f, 1.0);
mglClearDepth(1.0);
mglSetProjectionMatrix(pm);
mglSetModelViewMatrix(mvm);
mglBindVertexShader(&vs);
mglBindPixelShader(&ps);
mglBindTexture(tex);
mglBindVertexBuffer(vb);
mglDrawVertexBuffer();
```

[![Screenshot1](https://github.com/gecko0307/minigl/raw/main/assets/screenshot.jpg)](https://github.com/gecko0307/minigl/raw/main/assets/screenshot.jpg)

## Features
- Fully platform-independent. SDL is only used to create a window, you can use MiniGL with any other multimedia framework
- The only dependency is [dlib](https://github.com/gecko0307/dlib)
- Very simple imperative API
- Basic graphics pipeline similar to ancient OpenGL
- Supports only triangles
- Renders vertex buffers (vertex position buffer + texture coordinate buffer + index buffer)
- Textures
- Nearest-neighbour and bilinear sampling (`mglEnable(MGL_BILINEAR_FILTER)`)
- Blending modes: alpha, additive, modulate
- Fog
- Vertex and pixel shaders!
- User-defined frame buffers

No fancy-schmancy modern features like mipmapping or lights 🤣 But they can be implemented on user side, of course.
