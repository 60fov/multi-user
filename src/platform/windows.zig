const std = @import("std");

const windows = std.os.windows;
const WINAPI = windows.WINAPI;

const win32 = @import("bindings/win32.zig");
const platform = @import("../platform.zig");
const input = @import("../input.zig");

const WINDOW_CLASS_NAME: windows.LPCSTR = "MULTI-USER_WC";

pub const ContextOptions = struct {
    pub const Profile = enum(windows.INT) {
        core = win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        compat = win32.WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
    };

    pub const Flags = enum(windows.INT) {
        debug = win32.WGL_CONTEXT_DEBUG_BIT_ARB,
        forward = win32.WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
    };

    pub const Version = struct {
        major: windows.INT,
        minor: windows.INT,
    };

    flags: Flags = .debug,
    profile: Profile = .core,
    version: Version = .{ .major = 4, .minor = 6 },
};

var wglCreateContextAttribsARB: *const fn (
    hdc: windows.HDC,
    hShareContext: ?windows.HGLRC,
    attribList: *const c_int,
) callconv(WINAPI) ?windows.HGLRC = undefined;

var wglChoosePixelFormatARB: *const fn (
    hdc: windows.HDC,
    piAttribIList: *const windows.INT,
    pfAttribFList: ?*const windows.FLOAT,
    nMaxFormats: windows.UINT,
    piFormats: *windows.INT,
    nNumFormats: *windows.UINT,
) callconv(WINAPI) windows.BOOL = undefined;

pub fn getProcAddress(fn_name: [*:0]const u8) ?*anyopaque {
    if (win32.wglGetProcAddress(fn_name)) |func| {
        return func;
    } else {
        return win32.GetProcAddress(win32.GetModuleHandleA("opengl32.dll"), fn_name);
    }
}

pub fn initOpenGLContext(real_dc: windows.HDC, options: ContextOptions) !void {
    { // init opengl context extentions
        // create dummy window
        const dummy_window_class: win32.WNDCLASSEXA = .{
            .cbSize = @sizeOf(win32.WNDCLASSEXA),
            .style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
            .lpfnWndProc = Window.defaultWindowMsgProc,
            .hInstance = @ptrCast(win32.GetModuleHandleA(null)),
            .lpszClassName = "Dummy_WGL_beefyweefy",
        };

        if (win32.RegisterClassExA(&dummy_window_class) == windows.FALSE) {
            try getLastError();
        }

        const dummy_handle = win32.CreateWindowExA(
            0,
            dummy_window_class.lpszClassName,
            "Dummy OpenGL Window",
            0,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            null,
            null,
            dummy_window_class.hInstance,
            null,
        ) orelse {
            try getLastError();
            return;
        };

        const dummy_dc = win32.GetDC(dummy_handle);

        const pfd: win32.PIXELFORMATDESCRIPTOR = .{
            .nSize = @sizeOf(win32.PIXELFORMATDESCRIPTOR),
            .nVersion = 1,
            .dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER,
            .iPixelType = win32.PFD_TYPE_RGBA,
            .cColorBits = 32,
            .cDepthBits = 24,
            .cStencilBits = 8,
        };

        const pixel_format = win32.ChoosePixelFormat(dummy_dc, &pfd);

        if (win32.SetPixelFormat(dummy_dc, pixel_format, &pfd) == windows.FALSE) {
            try getLastError();
        }

        if (win32.wglCreateContext(dummy_dc)) |hglrc| {
            if (win32.wglMakeCurrent(dummy_dc, hglrc) == windows.FALSE) {
                try getLastError();
            }

            if (getProcAddress("wglCreateContextAttribsARB")) |func| {
                wglCreateContextAttribsARB = @ptrCast(func);
            } else {
                try getLastError();
            }

            if (getProcAddress("wglChoosePixelFormatARB")) |func| {
                wglChoosePixelFormatARB = @ptrCast(func);
            } else {
                try getLastError();
            }

            std.debug.print("loaded gl ext funcs", .{});

            _ = win32.wglMakeCurrent(dummy_dc, null);
            _ = win32.wglDeleteContext(hglrc);
            _ = win32.ReleaseDC(dummy_handle, dummy_dc);
            _ = win32.DestroyWindow(dummy_handle);
        } else {
            try getLastError();
        }
    }

    // // Now we can choose a pixel format the modern way, using wglChoosePixelFormatARB.
    const pixel_format_attribs = [_]windows.INT{
        win32.WGL_DRAW_TO_WINDOW_ARB, win32.GL_TRUE,
        win32.WGL_SUPPORT_OPENGL_ARB, win32.GL_TRUE,
        win32.WGL_DOUBLE_BUFFER_ARB,  win32.GL_TRUE,
        win32.WGL_ACCELERATION_ARB,   win32.WGL_FULL_ACCELERATION_ARB,
        win32.WGL_PIXEL_TYPE_ARB,     win32.WGL_TYPE_RGBA_ARB,
        win32.WGL_COLOR_BITS_ARB,     32,
        win32.WGL_DEPTH_BITS_ARB,     24,
        win32.WGL_STENCIL_BITS_ARB,   8,
        0,
    };

    var pixel_format: windows.INT = undefined;
    var num_formats: windows.UINT = undefined;
    if (wglChoosePixelFormatARB(real_dc, @ptrCast(&pixel_format_attribs), null, 1, &pixel_format, &num_formats) == win32.GL_FALSE) {
        try getLastError();
    }
    if (num_formats == 0) {
        std.debug.print("no matching pixel formats were found", .{});
        return;
    }

    var pfd: win32.PIXELFORMATDESCRIPTOR = undefined;
    if (win32.DescribePixelFormat(real_dc, pixel_format, @sizeOf(win32.PIXELFORMATDESCRIPTOR), &pfd) == 0) {
        try getLastError();
    }

    if (win32.SetPixelFormat(real_dc, pixel_format, &pfd) == windows.FALSE) {
        try getLastError();
    }

    const attribs = [_]windows.INT{
        win32.WGL_CONTEXT_MAJOR_VERSION_ARB, options.version.major,
        win32.WGL_CONTEXT_MINOR_VERSION_ARB, options.version.minor,
        win32.WGL_CONTEXT_PROFILE_MASK_ARB,  @intFromEnum(options.profile),
        win32.WGL_CONTEXT_FLAGS_ARB,         @intFromEnum(options.flags),
        0,
    };

    if (wglCreateContextAttribsARB(real_dc, null, @ptrCast(&attribs))) |hglrc| {
        if (win32.wglMakeCurrent(real_dc, hglrc) == windows.FALSE) {
            try getLastError();
        }
    } else {
        try getLastError();
    }
}

pub const Window = struct {
    allocator: std.mem.Allocator,
    handle: windows.HWND,

    pub fn init(allocator: std.mem.Allocator, title: [*:0]const u8, width: i32, height: i32) !Window {
        const hInstance: windows.HINSTANCE = @ptrCast(win32.GetModuleHandleA(null));

        const window_class: win32.WNDCLASSEXA = .{
            .cbSize = @sizeOf(win32.WNDCLASSEXA),
            .style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
            .hInstance = hInstance,
            .hCursor = win32.LoadCursorA(null, win32.IDC_ARROW),
            .lpfnWndProc = Window.defaultWindowMsgProc,
            .lpszClassName = WINDOW_CLASS_NAME,
        };

        if (win32.RegisterClassExA(&window_class) == windows.FALSE) {
            try getLastError();
        }

        var client_rect: windows.RECT = .{
            .top = 0,
            .left = 0,
            .right = width,
            .bottom = height,
        };
        _ = win32.AdjustWindowRect(&client_rect, win32.WS_OVERLAPPEDWINDOW, 0);
        const cw = client_rect.right - client_rect.left;
        const ch = client_rect.bottom - client_rect.top;
        const handle = win32.CreateWindowExA(
            0,
            WINDOW_CLASS_NAME,
            title,
            win32.WS_OVERLAPPEDWINDOW,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            cw,
            ch,
            null,
            null,
            hInstance,
            null,
        ) orelse {
            const code = win32.GetLastError();
            std.debug.print("null wnd handle, last error code: {d}\n", .{code});
            return error.FailedWindowCreation;
        };

        return Window{
            .allocator = allocator,
            .handle = handle,
        };
    }

    pub fn show(self: *Window) void {
        _ = win32.ShowWindow(self.handle, win32.SW_SHOW);
    }

    pub fn deinit(self: *Window) void {
        if (win32.wglGetCurrentContext()) |gc| {
            if (win32.wglGetCurrentDC()) |dc| {
                _ = win32.wglMakeCurrent(null, null);
                _ = win32.ReleaseDC(self.handle, dc);
                _ = win32.wglDeleteContext(gc);
            }
        }

        _ = win32.ShowWindow(self.handle, win32.SW_HIDE);
        if (win32.DestroyWindow(self.handle) == windows.FALSE) {
            // failed to destroy window
            getLastError() catch {};
        }

        if (win32.UnregisterClassA(
            WINDOW_CLASS_NAME,
            @ptrCast(win32.GetModuleHandleA(null)),
        ) == windows.FALSE) {
            getLastError() catch {};
        }
    }

    pub fn present(self: *Window) void {
        const dc = win32.GetDC(self.handle);
        _ = win32.SwapBuffers(dc);
        _ = win32.ReleaseDC(self.handle, dc);
    }

    pub fn poll(self: *Window) void {
        var msg: win32.MSG = undefined;
        while (win32.PeekMessageA(&msg, self.handle, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageA(&msg);
        }
    }

    /// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wndproc
    fn defaultWindowMsgProc(
        hwnd: windows.HWND,
        msg: windows.UINT,
        wParam: windows.WPARAM,
        lParam: windows.LPARAM,
    ) callconv(WINAPI) windows.LRESULT {
        switch (msg) {
            // win32.WM_CREATE => {},
            win32.WM_CLOSE => {
                platform.quit();
            },

            win32.WM_MOUSEMOVE => {
                // https://learn.microsoft.com/en-us/windows/win32/api/windowsx/nf-windowsx-get_x_lparam
                input._mouse.x = @intCast(lParam & 0xffff);
                input._mouse.y = @intCast((lParam >> 16) & 0xffff);
            },

            win32.WM_LBUTTONDOWN => input._mouse.button.left = true,
            win32.WM_MBUTTONDOWN => input._mouse.button.middle = true,
            win32.WM_RBUTTONDOWN => input._mouse.button.right = true,
            win32.WM_LBUTTONUP => input._mouse.button.left = false,
            win32.WM_MBUTTONUP => input._mouse.button.middle = false,
            win32.WM_RBUTTONUP => input._mouse.button.right = false,

            win32.WM_XBUTTONDOWN => {
                if (wParam >> 16 & win32.XBUTTON1 != 0) {
                    input._mouse.button.x1 = true;
                } else {
                    input._mouse.button.x2 = true;
                }
            },
            win32.WM_XBUTTONUP => {
                if (wParam >> 16 & win32.XBUTTON1 != 0) {
                    input._mouse.button.x1 = false;
                } else {
                    input._mouse.button.x2 = false;
                }
            },
            // TODO https://stackoverflow.com/questions/5681284/how-do-i-distinguish-between-left-and-right-keys-ctrl-and-alt
            win32.WM_SYSKEYDOWN, win32.WM_KEYDOWN => {
                const was_down = lParam & (1 << 30) != 0;
                if (!was_down) {
                    const key_code: u8 = @truncate(wParam);
                    const new_state = input.Keyboard.KeyState{
                        .down = true,
                        .just = true,
                    };
                    input._keyboard.keys[key_code] = new_state;
                }
            },
            win32.WM_SYSKEYUP, win32.WM_KEYUP => {
                const key_code: u8 = @truncate(wParam);
                const new_state = input.Keyboard.KeyState{
                    .down = false,
                    .just = true,
                };
                input._keyboard.keys[key_code] = new_state;
            },
            else => {
                return win32.DefWindowProcA(hwnd, msg, wParam, lParam);
            },
        }
        return 0;
    }
};

fn getLastError() !void {
    const code = win32.GetLastError();
    switch (code) {
        87 => return error.ErrorInvalidParameter,
        else => {
            std.debug.print("unhandled win32 error code: {d}\n", .{code});
            unreachable;
        },
    }
}
