const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

const wingdi = @import("wingdi.zig");
const windef = @import("windef.zig");

pub const WM_CLOSE: windows.UINT = 0x0010;
pub const WM_CREATE: windows.UINT = 0x0001;
pub const WM_INPUT: windows.UINT = 0x00FF;
pub const WM_MOUSEMOVE: windows.UINT = 0x0200;
pub const WM_KEYDOWN: windows.UINT = 0x0100;
pub const WM_KEYUP: windows.UINT = 0x0101;
pub const WM_SYSKEYDOWN: windows.UINT = 0x0104;
pub const WM_SYSKEYUP: windows.UINT = 0x0105;
pub const WM_LBUTTONDOWN: windows.UINT = 0x0201;
pub const WM_LBUTTONUP: windows.UINT = 0x0202;
pub const WM_MBUTTONDOWN: windows.UINT = 0x0207;
pub const WM_MBUTTONUP: windows.UINT = 0x0208;
pub const WM_RBUTTONDOWN: windows.UINT = 0x0204;
pub const WM_RBUTTONUP: windows.UINT = 0x0205;
pub const WM_XBUTTONDOWN: windows.UINT = 0x020B;
pub const WM_XBUTTONUP: windows.UINT = 0x020C;

/// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-xbuttondown
pub const XBUTTON1: windows.UINT = 0x0001;
pub const XBUTTON2: windows.UINT = 0x0002;

pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;
pub const CS_OWNDC = 0x0020;

pub const WS_OVERLAPPED: u32 = 0x00000000;
pub const WS_POPUP: u32 = 0x80000000;
pub const WS_CHILD: u32 = 0x40000000;
pub const WS_MINIMIZE: u32 = 0x20000000;
pub const WS_VISIBLE: u32 = 0x10000000;
pub const WS_DISABLED: u32 = 0x08000000;
pub const WS_CLIPSIBLINGS: u32 = 0x04000000;
pub const WS_CLIPCHILDREN: u32 = 0x02000000;
pub const WS_MAXIMIZE: u32 = 0x01000000;
pub const WS_CAPTION: u32 = 0x00C00000; // /* WS_BORDER | WS_DLGFRAME  */
pub const WS_BORDER: u32 = 0x00800000;
pub const WS_DLGFRAME: u32 = 0x00400000;
pub const WS_VSCROLL: u32 = 0x00200000;
pub const WS_HSCROLL: u32 = 0x00100000;
pub const WS_SYSMENU: u32 = 0x00080000;
pub const WS_THICKFRAME: u32 = 0x00040000;
pub const WS_GROUP: u32 = 0x00020000;
pub const WS_TABSTOP: u32 = 0x00010000;

pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED |
    WS_CAPTION |
    WS_SYSMENU |
    WS_THICKFRAME |
    WS_MINIMIZEBOX |
    WS_MAXIMIZEBOX;

pub const PM_NOREMOVE: u32 = 0x0000;
pub const PM_REMOVE: u32 = 0x0001;
pub const PM_NOYIELD: u32 = 0x0002;

/// Hides the window and activates another window.
pub const SW_HIDE: i32 = 0;
/// Activates and displays a window. If the window is minimized, maximized, or arranged, the system restores it to its original size and position. An application should specify this flag when displaying the window for the first time.
pub const SW_SHOWNORMAL: i32 = 1;
/// see SW_SHOWNORMAL
pub const SW_NORMAL: i32 = 1;
/// Activates the window and displays it as a minimized window.
pub const SW_SHOWMINIMIZED: i32 = 2;
pub const SW_SHOWMAXIMIZED: i32 = 2;
/// Activates the window and displays it as a maximized window.
pub const SW_MAXIMIZE: i32 = 3;
/// Displays a window in its most recent size and position. This value is similar to SW_SHOWNORMAL, except that the window is not activated.
pub const SW_SHOWNOACTIVATE: i32 = 4;
/// Activates the window and displays it in its current size and position.
pub const SW_SHOW: i32 = 5;
/// Minimizes the specified window and activates the next top-level window in the Z order.
pub const SW_MINIMIZE: i32 = 6;
/// Displays the window as a minimized window. This value is similar to SW_SHOWMINIMIZED, except the window is not activated.
pub const SW_SHOWMINNOACTIVE: i32 = 7;
/// Displays the window in its current size and position. This value is similar to SW_SHOW, except that the window is not activated.
pub const SW_SHOWNA: i32 = 8;
/// Activates and displays the window. If the window is minimized, maximized, or arranged, the system restores it to its original size and position. An application should specify this flag when restoring a minimized window.
pub const SW_RESTORE: i32 = 9;
/// Sets the show state based on the SW_ value specified in the STARTUPINFO structure passed to the CreateProcess function by the program that started the application.
pub const SW_SHOWDEFAULT: i32 = 10;
/// Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when minimizing windows from a different thread.
pub const SW_FORCEMINIMIZE: i32 = 11;

// TODO
pub const IDC_ARROW: windows.LPCSTR = @ptrFromInt(32512);

const WNDCLASS_STYLES = enum(u32) {
    VREDRAW = 1,
    HREDRAW = 2,
    DBLCLKS = 8,
    OWNDC = 32,
    CLASSDC = 64,
    PARENTDC = 128,
    NOCLOSE = 512,
    SAVEBITS = 2048,
    BYTEALIGNCLIENT = 4096,
    BYTEALIGNWINDOW = 8192,
    GLOBALCLASS = 16384,
    IME = 65536,
    DROPSHADOW = 131072,
    _,
};

pub const WINDOW_STYLE = enum(u32) {
    OVERLAPPED = 0,
    POPUP = 2147483648,
    CHILD = 1073741824,
    MINIMIZE = 536870912,
    VISIBLE = 268435456,
    DISABLED = 134217728,
    CLIPSIBLINGS = 67108864,
    CLIPCHILDREN = 33554432,
    MAXIMIZE = 16777216,
    CAPTION = 12582912,
    BORDER = 8388608,
    DLGFRAME = 4194304,
    VSCROLL = 2097152,
    HSCROLL = 1048576,
    SYSMENU = 524288,
    THICKFRAME = 262144,
    GROUP = 131072,
    TABSTOP = 65536,
    // MINIMIZEBOX = 131072, this enum value conflicts with GROUP
    // MAXIMIZEBOX = 65536, this enum value conflicts with TABSTOP
    // TILED = 0, this enum value conflicts with OVERLAPPED
    // ICONIC = 536870912, this enum value conflicts with MINIMIZE
    // SIZEBOX = 262144, this enum value conflicts with THICKFRAME
    TILEDWINDOW = 13565952,
    // OVERLAPPEDWINDOW = 13565952, this enum value conflicts with TILEDWINDOW
    POPUPWINDOW = 2156396544,
    // CHILDWINDOW = 1073741824, this enum value conflicts with CHILD
    ACTIVECAPTION = 1,
    _,
};

pub const SHOW_WINDOW_CMD = enum(u32) {
    FORCEMINIMIZE = 11,
    HIDE = 0,
    MAXIMIZE = 3,
    MINIMIZE = 6,
    RESTORE = 9,
    SHOW = 5,
    SHOWDEFAULT = 10,
    // SHOWMAXIMIZED = 3, this enum value conflicts with MAXIMIZE
    SHOWMINIMIZED = 2,
    SHOWMINNOACTIVE = 7,
    SHOWNA = 8,
    SHOWNOACTIVATE = 4,
    SHOWNORMAL = 1,
    // NORMAL = 1, this enum value conflicts with SHOWNORMAL
    // MAX = 11, this enum value conflicts with FORCEMINIMIZE
    // PARENTCLOSING = 1, this enum value conflicts with SHOWNORMAL
    // OTHERZOOM = 2, this enum value conflicts with SHOWMINIMIZED
    // PARENTOPENING = 3, this enum value conflicts with MAXIMIZE
    // OTHERUNZOOM = 4, this enum value conflicts with SHOWNOACTIVATE
    // SCROLLCHILDREN = 1, this enum value conflicts with SHOWNORMAL
    // INVALIDATE = 2, this enum value conflicts with SHOWMINIMIZED
    // ERASE = 4, this enum value conflicts with SHOWNOACTIVATE
    SMOOTHSCROLL = 16,
    _,
};

pub const SW_MAX = SHOW_WINDOW_CMD.FORCEMINIMIZE;
pub const SW_PARENTCLOSING = SHOW_WINDOW_CMD.SHOWNORMAL;
pub const SW_OTHERZOOM = SHOW_WINDOW_CMD.SHOWMINIMIZED;
pub const SW_PARENTOPENING = SHOW_WINDOW_CMD.MAXIMIZE;
pub const SW_OTHERUNZOOM = SHOW_WINDOW_CMD.SHOWNOACTIVATE;
pub const SW_SCROLLCHILDREN = SHOW_WINDOW_CMD.SHOWNORMAL;
pub const SW_INVALIDATE = SHOW_WINDOW_CMD.SHOWMINIMIZED;
pub const SW_ERASE = SHOW_WINDOW_CMD.SHOWNOACTIVATE;
pub const SW_SMOOTHSCROLL = SHOW_WINDOW_CMD.SMOOTHSCROLL;

pub const CW_USEDEFAULT = @as(i32, -2147483648);

pub const DIB_USAGE = enum(u32) {
    RGB_COLORS = 0,
    PAL_COLORS = 1,
};

pub const DIB_RGB_COLORS: u32 = 0;
pub const DIB_PAL_COLORS: u32 = 0;

pub const RIDEV_NOLEGACY: windows.DWORD = 0x00000030;
pub const RIDEV_CAPTUREMOUSE: windows.DWORD = 0x00000200;
pub const RIDEV_DEVNOTIFY: windows.DWORD = 0x00002000;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getrawinputdata#parameters
pub const RID_HEADER: windows.UINT = 0x10000005;
pub const RID_INPUT: windows.UINT = 0x10000003;

/// https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/hid-usages#usage-page
pub const HID_USAGE_PAGE_GENERIC: windows.USHORT = 0x01;
pub const HID_USAGE_GENERIC_MOUSE: windows.USHORT = 0x02;
pub const HID_USAGE_GENERIC_KEYBOARD: windows.USHORT = 0x06;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawinputheader#members
pub const RIM_TYPEMOUSE: windows.DWORD = 0;
pub const RIM_TYPEKEYBOARD: windows.DWORD = 1;
pub const RIM_TYPEHID: windows.DWORD = 2;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawmouse#members
pub const MOUSE_MOVE_RELATIVE = 0x00;
pub const MOUSE_MOVE_ABSOLUTE = 0x01;
pub const MOUSE_VIRTUAL_DESKTOP = 0x02;
pub const MOUSE_ATTRIBUTES_CHANGED = 0x04;
pub const MOUSE_MOVE_NOCOALESCE = 0x0;

pub const RI_MOUSE_BUTTON_1_DOWN = 0x0001;
pub const RI_MOUSE_LEFT_BUTTON_DOWN = 0x0001;
pub const RI_MOUSE_BUTTON_1_UP = 0x0002;
pub const RI_MOUSE_LEFT_BUTTON_UP = 0x0002;
pub const RI_MOUSE_BUTTON_2_DOWN = 0x0004;
pub const RI_MOUSE_RIGHT_BUTTON_DOWN = 0x0004;
pub const RI_MOUSE_BUTTON_2_UP = 0x0008;
pub const RI_MOUSE_RIGHT_BUTTON_UP = 0x0008;
pub const RI_MOUSE_BUTTON_3_DOWN = 0x0010;
pub const RI_MOUSE_MIDDLE_BUTTON_DOWN = 0x0010;
pub const RI_MOUSE_BUTTON_3_UP = 0x0020;
pub const RI_MOUSE_MIDDLE_BUTTON_UP = 0x0020;
pub const RI_MOUSE_BUTTON_4_DOWN = 0x0040;
pub const RI_MOUSE_BUTTON_4_UP = 0x0080;
pub const RI_MOUSE_BUTTON_5_DOWN = 0x0100;
pub const RI_MOUSE_BUTTON_5_UP = 0x020;
pub const RI_MOUSE_WHEEL = 0x0400;
pub const RI_MOUSE_HWHEEL = 0x0800;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetrics
pub const SM_CXSCREEN: windows.INT = 0;
pub const SM_CYSCREEN: windows.INT = 1;
pub const SM_XVIRTUALSCREEN: windows.INT = 76;
pub const SM_YVIRTUALSCREEN: windows.INT = 77;
pub const SM_CXVIRTUALSCREEN: windows.INT = 78;
pub const SM_CYVIRTUALSCREEN: windows.INT = 79;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-wndclassexa
pub const WNDCLASSEXA = extern struct {
    cbSize: windows.UINT,
    style: windows.UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: windows.HINSTANCE,
    hIcon: ?windows.HICON = null,
    hCursor: ?windows.HCURSOR = null,
    hbrBackground: ?windows.HBRUSH = null,
    lpszMenuName: ?windows.LPCSTR = null,
    lpszClassName: windows.LPCSTR,
    hIconSm: ?windows.HICON = null,
};

pub const MSG = extern struct {
    hwnd: windows.HWND,
    message: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM,
    time: windows.DWORD,
    pt: windows.POINT,
    lPrivate: windows.DWORD,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawinputdevice
pub const RAWINPUTDEVICE = extern struct {
    usUsagePage: windows.USHORT,
    usUsage: windows.USHORT,
    dwFlags: windows.DWORD,
    hwndTarget: ?windows.HWND,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawinput
pub const RAWINPUT = extern struct {
    header: RAWINPUTHEADER,
    data: union {
        mouse: RAWMOUSE,
        keyboard: RAWKEYBOARD,
        hid: RAWHID,
    },
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawmouse
pub const RAWMOUSE = extern struct {
    usFlags: windows.USHORT,
    DUMMYUNIONNAME: union {
        ulButtons: windows.ULONG,
        DUMMYSTRUCTNAME: struct {
            usButtonFlags: windows.USHORT,
            usButtonData: windows.USHORT,
        },
    },
    ulRawButtons: windows.ULONG,
    lLastX: windows.LONG,
    lLastY: windows.LONG,
    ulExtraInformation: windows.ULONG,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawkeyboard
pub const RAWKEYBOARD = extern struct {
    MakeCode: windows.USHORT,
    Flags: windows.USHORT,
    Reserved: windows.USHORT,
    VKey: windows.USHORT,
    Message: windows.UINT,
    ExtraInformation: windows.ULONG,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawhid
pub const RAWHID = extern struct {
    dwSizeHid: windows.DWORD,
    dwCount: windows.DWORD,
    bRawData: [1]windows.BYTE,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawinputheader
pub const RAWINPUTHEADER = extern struct {
    dwType: windows.DWORD,
    dwSize: windows.DWORD,
    hDevice: windows.HANDLE,
    wParam: windows.WPARAM,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawinputdevice
pub const WNDPROC = *const fn (
    param0: windows.HWND,
    param1: u32,
    param2: windows.WPARAM,
    param3: windows.LPARAM,
) callconv(WINAPI) windows.LRESULT;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadcursora
pub extern "user32" fn LoadCursorA(
    hInstance: ?windows.HINSTANCE,
    lpCursorName: windows.LPCSTR,
) callconv(WINAPI) ?windows.HCURSOR;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerclassexa
pub extern "user32" fn RegisterClassExA(unnamedParam1: *const WNDCLASSEXA) windows.ATOM;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-adjustwindowrect
pub extern "user32" fn AdjustWindowRect(lpRect: *windows.RECT, dwStyle: windows.DWORD, bMenu: windows.BOOL) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-createwindowexa
pub extern "user32" fn CreateWindowExA(
    dwExStyle: windows.DWORD,
    lpClassName: ?windows.LPCSTR,
    lpWindowName: ?windows.LPCSTR,
    dwStyle: windows.DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?windows.HWND,
    hMenu: ?windows.HMENU,
    hInstance: ?windows.HINSTANCE,
    lpParam: ?windows.LPVOID,
) callconv(WINAPI) ?windows.HWND;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow
pub extern "user32" fn ShowWindow(hWnd: windows.HWND, nCmdShow: i32) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-destroywindow
pub extern "user32" fn DestroyWindow(hWnd: windows.HWND) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-defwindowproca
pub extern "user32" fn DefWindowProcA(
    hWnd: windows.HWND,
    Msg: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM,
) callconv(WINAPI) windows.LRESULT;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-unregisterclassa
pub extern "user32" fn UnregisterClassA(
    lpClassName: windows.LPCSTR,
    hInstance: ?windows.HINSTANCE,
) callconv(WINAPI) windows.BOOL;

pub extern "user32" fn GetDC(hWnd: windows.HWND) windows.HDC;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-releasedc
pub extern "user32" fn ReleaseDC(
    hWnd: windows.HWND,
    hDC: windows.HDC,
) callconv(WINAPI) i32;

pub extern "user32" fn PeekMessageA(
    lpMsg: *MSG,
    hWnd: ?windows.HWND,
    wMsgFilterMin: windows.UINT,
    wMsgFilterMax: windows.UINT,
    wRemoveMsg: windows.UINT,
) callconv(WINAPI) windows.BOOL;

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) windows.BOOL;

pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) windows.LRESULT;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerrawinputdevices
pub extern "user32" fn RegisterRawInputDevices(
    pRawInputDevices: *RAWINPUTDEVICE,
    uiNumDevices: windows.UINT,
    cbSize: windows.UINT,
) callconv(WINAPI) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getrawinputdata
pub extern "user32" fn GetRawInputData(
    /// handle to RAWINPUT
    hRawInput: *anyopaque,
    uiCommand: windows.UINT,
    pData: ?windows.LPVOID,
    pcbSize: *windows.UINT,
    cbSizeHeader: windows.UINT,
) callconv(WINAPI) windows.UINT;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetrics
pub extern "user32" fn GetSystemMetrics(
    nIndex: windows.INT,
) callconv(WINAPI) windows.INT;
