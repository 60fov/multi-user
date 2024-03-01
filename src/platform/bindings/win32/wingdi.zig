const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

pub const BI_RGB = @as(i32, 0);

pub const PFD_DRAW_TO_WINDOW = 0x00000004;
pub const PFD_SUPPORT_OPENGL = 0x00000020;
pub const PFD_DOUBLEBUFFER = 0x00000001;
pub const PFD_TYPE_RGBA = 0;

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
pub const BITMAPINFOHEADER = extern struct {
    biSize: windows.DWORD,
    biWidth: windows.LONG,
    biHeight: windows.LONG,
    biPlanes: windows.WORD,
    biBitCount: windows.WORD,
    biCompression: windows.DWORD,
    biSizeImage: windows.DWORD = 0,
    biXPelsPerMeter: windows.LONG = 0,
    biYPelsPerMeter: windows.LONG = 0,
    biClrUsed: windows.DWORD = 0,
    biClrImportant: windows.DWORD = 0,
};

pub const RGBQUAD = extern struct {
    rgbBlue: windows.BYTE = 0,
    rgbGreen: windows.BYTE = 0,
    rgbRed: windows.BYTE = 0,
    rgbReserved: windows.BYTE = 0,
};

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: windows.WORD,
    nVersion: windows.WORD,
    dwFlags: windows.DWORD,
    iPixelType: windows.BYTE,
    cColorBits: windows.BYTE,
    cRedBits: windows.BYTE = 0,
    cRedShift: windows.BYTE = 0,
    cGreenBits: windows.BYTE = 0,
    cGreenShift: windows.BYTE = 0,
    cBlueBits: windows.BYTE = 0,
    cBlueShift: windows.BYTE = 0,
    cAlphaBits: windows.BYTE = 0,
    cAlphaShift: windows.BYTE = 0,
    cAccumBits: windows.BYTE = 0,
    cAccumRedBits: windows.BYTE = 0,
    cAccumGreenBits: windows.BYTE = 0,
    cAccumBlueBits: windows.BYTE = 0,
    cAccumAlphaBits: windows.BYTE = 0,
    cDepthBits: windows.BYTE,
    cStencilBits: windows.BYTE,
    cAuxBuffers: windows.BYTE = 0,
    iLayerType: windows.BYTE = 0,
    bReserved: windows.BYTE = 0,
    dwLayerMask: windows.DWORD = 0,
    dwVisibleMask: windows.DWORD = 0,
    dwDamageMask: windows.DWORD = 0,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-setdibitstodevice
pub extern "gdi32" fn SetDIBitsToDevice(
    hdc: windows.HDC,
    xDest: i32,
    yDest: i32,
    w: windows.DWORD,
    h: windows.DWORD,
    xSrc: i32,
    ySrc: i32,
    StartScan: windows.UINT,
    cLines: windows.UINT,
    lpvBits: *const anyopaque,
    lpbmi: *const BITMAPINFO,
    ColorUse: windows.UINT,
) callconv(WINAPI) i32;

// opengl32
/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-choosepixelformat
pub extern "gdi32" fn ChoosePixelFormat(
    hdc: windows.HDC,
    ppfd: *const PIXELFORMATDESCRIPTOR,
) callconv(WINAPI) windows.INT;

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-setpixelformat
pub extern "gdi32" fn SetPixelFormat(
    hdc: windows.HDC,
    format: windows.INT,
    ppfd: *const PIXELFORMATDESCRIPTOR,
) callconv(WINAPI) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-describepixelformat
pub extern "gdi32" fn DescribePixelFormat(
    hdc: windows.HDC,
    iPixelFormat: windows.INT,
    nBytes: windows.UINT,
    ppfd: *PIXELFORMATDESCRIPTOR,
) callconv(WINAPI) windows.INT;

pub extern "gdi32" fn SwapBuffers(
    unnamedParam1: windows.HDC,
) callconv(WINAPI) windows.BOOL;

pub extern "opengl32" fn wglCreateContext(
    unnamedParam1: windows.HDC,
) callconv(WINAPI) ?windows.HGLRC;

pub extern "opengl32" fn wglMakeCurrent(
    unnamedParam1: ?windows.HDC,
    unnamedParam2: ?windows.HGLRC,
) callconv(WINAPI) windows.BOOL;

pub extern "opengl32" fn wglDeleteContext(
    unnamedParam1: windows.HGLRC,
) callconv(WINAPI) windows.BOOL;

pub extern "opengl32" fn wglGetCurrentContext() callconv(WINAPI) ?windows.HGLRC;
pub extern "opengl32" fn wglGetCurrentDC() callconv(WINAPI) ?windows.HDC;

pub extern "opengl32" fn wglGetProcAddress(
    unnamedParam1: windows.LPCSTR,
) callconv(WINAPI) ?windows.PROC;
