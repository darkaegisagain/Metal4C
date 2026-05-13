# Metal4C

Metal4C is a C-based rendering library built on top of Apple's Metal API with an OpenGL-inspired programming model.

The goal of the project is to provide:

* A clean C API for Metal
* An immediate-mode style rendering workflow
* Deferred state binding similar to legacy OpenGL semantics
* A lightweight abstraction layer over Metal objects
* Cross-language compatibility for future bindings
* A foundation for remote/network rendering concepts similar to GLX

The project is currently focused on macOS and Apple Silicon systems using Metal.

---

# Project Goals

Metal4C is not intended to be a minimal wrapper over Metal.

Instead, the design philosophy is:

* Present a familiar OpenGL-like rendering interface
* Internally translate state into efficient Metal command encoding
* Delay Metal state binding until draw submission
* Keep the external API simple and procedural
* Allow future bindings from languages such as Python, Lisp, and Fortran

The long-term direction is to support:

* Immediate-mode rendering
* Retained rendering paths
* User-defined vertex layouts
* Remote rendering protocols
* Display-list style batching
* Multi-language graphics bindings

---

# Current Features

## Rendering

* Metal-backed rendering pipeline
* Indexed and non-indexed drawing
* Dynamic vertex buffer generation
* Deferred render state tracking
* Immediate-mode style submission
* Texture support
* Shader library loading
* MTKView integration

## Windowing / Events

* Cocoa + Objective-C backend
* NSWindow management
* Mouse input handling
* Keyboard input handling
* Scroll wheel handling
* Window lifecycle management

## Shader Support

* Runtime shader compilation
* Shader loading from source strings
* Shader loading from external `.metal` files
* Planned precompiled `.metallib` support

---

# Repository Layout

```text
Metal4C/
├── Metal4C_Framework/
├── include/
├── shaders/
├── examples/
├── tests/
└── docs/
```

The exact structure may evolve as the framework stabilizes.

---

# Design Philosophy

## Deferred Binding

Metal4C tracks rendering state internally and only applies Metal state when required by a draw call.

This mirrors traditional OpenGL behavior while still allowing Metal to perform efficiently.

Examples of tracked state include:

* Render pipeline state
* Vertex buffers
* Index buffers
* Textures
* Blend state
* Depth state
* Vertex layouts

Dirty flags are used internally to minimize unnecessary Metal state updates.

---

## Vertex Arrays and Buffers

Metal4C separates:

* Vertex buffer storage
* Vertex attribute layout description

This is conceptually similar to OpenGL VAOs and VBOs.

The intent is:

* Vertex arrays describe layout semantics
* Vertex buffers provide storage
* Buffers may be rebound independently
* Draw calls resolve the final Metal binding state

Future versions are expected to support fully user-defined vertex descriptors.

---

## Cross-Language API Design

A major design goal is ABI stability and language interoperability.

The API is intentionally procedural and handle-based.

Planned characteristics:

* Opaque integer handles
* Minimal dependency on Objective-C outside platform layers
* Stable C ABI
* Suitability for bindings in:

  * Python
  * Fortran
  * Common Lisp
  * Other native languages

---

# Building

## Requirements

* macOS
* Xcode
* Metal-capable GPU
* Apple Metal SDK

## Build Using Xcode

1. Open the Xcode project
2. Select the desired target
3. Build the framework or example application

Current development is focused on:

* Debug builds
* Local framework loading
* Runtime shader compilation

---

# Shader Includes

Metal shader source may include Metal4C shader headers:

```metal
#include <Metal4c/metal4c_shader_types.h>
```

When compiling shaders dynamically, the Metal compiler must be able to locate the include directory.

Possible approaches:

* Runtime include path configuration
* Bundled shader resources
* Precompiled `.metallib` packaging

---

# Framework and Runtime Notes

The project currently experiments with:

* `.framework` packaging
* `.dylib` packaging
* `@rpath` handling
* Local developer installs
* Runtime shader resource loading
* Code signing behavior

On macOS, command-line applications may require additional runtime path configuration for frameworks.

---

# Example Usage

```c
MTuint shader_lib;

shader_lib = mtCreateShaderLibraryFromFile("mandelbrot_shader.metal");
```

Example rendering flow:

```c
mtBegin(MT_TRIANGLES);
mtColor4f(1.0f, 0.0f, 0.0f, 1.0f);
mtVertex3f(0.0f, 0.5f, 0.0f);
mtVertex3f(-0.5f, -0.5f, 0.0f);
mtVertex3f(0.5f, -0.5f, 0.0f);
mtEnd();
```

---

# Current Development Areas

Active development currently includes:

* Framework restructuring
* Shader library management
* Vertex engine cleanup
* Indexed rendering fixes
* Drawable lifecycle correctness
* Event system expansion
* Metallib packaging
* Resource loading
* API cleanup

---

# Roadmap

Planned or experimental features:

* Precompiled metallib support
* Multiple shader pipelines
* User-defined vertex descriptors
* Display lists / batching
* Network rendering concepts
* Linux-compatible abstraction layers
* Vulkan-style backend experimentation
* Better texture management
* Multi-window support
* Advanced pipeline caching

---

# Status

Metal4C is an experimental and actively evolving project.

APIs, structures, and internal behavior may change significantly during development.

---

---

# Links

* GitHub Repository: [https://github.com/darkaegisagain/Metal4C](https://github.com/darkaegisagain/Metal4C)
