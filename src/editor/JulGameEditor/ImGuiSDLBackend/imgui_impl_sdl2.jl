#Reference: https://github.com/ocornut/imgui/blob/master/backends/imgui_impl_sdl2.cpp
include("structs.jl")

# TODO: Understand this and make it work in Julia
#ifdef __APPLE__
#include <TargetConditionals.h>
#endif
#ifdef __EMSCRIPTEN__
#include <emscripten/em_js.h>
#endif
#undef Status // X11 headers are leaking this.

#if SDL_VERSION_ATLEAST(2,0,4) && !defined(__EMSCRIPTEN__) && !defined(__ANDROID__) && !(defined(__APPLE__) && TARGET_OS_IOS) && !defined(__amigaos4__)
#define SDL_HAS_CAPTURE_AND_GLOBAL_MOUSE    1
#else
#define SDL_HAS_CAPTURE_AND_GLOBAL_MOUSE    0
#endif
#define SDL_HAS_PER_MONITOR_DPI             SDL_VERSION_ATLEAST(2,0,4)
#define SDL_HAS_VULKAN                      SDL_VERSION_ATLEAST(2,0,6)
#define SDL_HAS_OPEN_URL                    SDL_VERSION_ATLEAST(2,0,14)
#if SDL_HAS_VULKAN
#include <SDL_vulkan.h>
#endif
# TODO: END

function ImGui_ImplSDL2_SetClipboardText(user_data::Ptr{Cvoid}, text::Ptr{Cchar})
    SDL2.SDL_SetClipboardText(text)
end

function ImGui_ImplSDL2_GetClipboardText(user_data::Ptr{Cvoid})::Ptr{Cchar}
    bd = ImGui_ImplSDL2_GetBackendData()
    if (bd.ClipboardTextData != C_NULL && bd.ClipboardTextData !== nothing)
        SDL2.SDL_free(bd.ClipboardTextData)
    end
    bd.ClipboardTextData = SDL2.SDL_GetClipboardText()
    return bd.ClipboardTextData
end

# struct ImGuiPlatformImeData
#     {
#         bool WantVisible;
#         bool WantTextInput;
#         ImVec2 InputPos;
#         float InputLineHeight;
#         ImGuiID ViewportId;
#     };
function ImGui_ImplSDL2_PlatformSetImeData(data::Ptr{CImGui.ImGuiPlatformImeData})
    want_visible = unsafe_load(Ptr{Bool}(data + offsetof(CImGui.ImGuiPlatformImeData, Val(:WantVisible))))
    input_pos = unsafe_load(Ptr{CImGui.ImVec2}(data + 8))#offsetof(CImGui.ImGuiPlatformImeData, Val(:InputPos))))
    input_line_height = unsafe_load(Ptr{Float32}(data + 12))#offsetof(CImGui.ImGuiPlatformImeData, Val(:InputLineHeight))))
    # viewport_id = unsafe_load(Ptr{CImGui.ImGuiID}(data + offsetof(CImGui.ImGuiPlatformImeData, Val(:ViewportId))))
    # want_text_input = unsafe_load(Ptr{Bool}(data + offsetof(CImGui.ImGuiPlatformImeData, Val(:WantTextInput))))
    # println("want_visible: ", want_visible)
    # println("input_pos: ", input_pos)
    # println("input_line_height: ", input_line_height)
    # println("viewport_id: ", viewport_id)
    # println("want_text_input: ", want_text_input)
    if want_visible
        r::SDL2.SDL_Rect = SDL2.SDL_Rect(
            Int32(input_pos.x),
            Int32(input_pos.y),
            1,
            Int32(input_line_height)
        )
        SDL2.SDL_SetTextInputRect(Ref(r))
    end
end

function ImGui_ImplSDL2_InitForOpenGL(window::Ptr{SDL2.SDL_Window}, sdl_gl_context::Ptr{Cvoid})::Bool
    return ImGui_ImplSDL2_Init(window, Ptr{SDL2.SDL_Renderer}(C_NULL), sdl_gl_context);
end

function ImGui_ImplSDL2_InitForSDLRenderer(window::Ptr{SDL2.SDL_Window}, renderer::Ptr{SDL2.SDL_Renderer})::Bool
    return ImGui_ImplSDL2_Init(window, renderer, Ptr{Cvoid}(C_NULL))
end

#ifdef __EMSCRIPTEN__
#EM_JS(void, ImGui_ImplSDL2_EmscriptenOpenURL, (char const* url), { url = url ? UTF8ToString(url) : null; if (url) window.open(url, '_blank'); });
#endif

function ImGui_ImplSDL2_Init(window::Ptr{SDL2.SDL_Window}, renderer::Ptr{SDL2.SDL_Renderer}, sdl_gl_context::Ptr{Cvoid})::Bool
    io = CImGui.GetIO()
    #CImGui.IMGUI_CHECKVERSION()
    @assert unsafe_load(io.BackendPlatformUserData) == C_NULL
    @assert SDL_VERSION_ATLEAST(Int32(2),Int32(0),Int32(4)) "SDL version must be at least 2.0.4"

    # Check and store if we are on a SDL backend that supports global mouse position
    # ("wayland" and "rpi" don't support it, but we chose to use a white-list instead of a black-list)
    mouse_can_use_global_state = false
    sdl_backend = SDL2.SDL_GetCurrentVideoDriver()
    global_mouse_whitelist = ["windows", "cocoa", "x11", "DIVE", "VMAN"]
    for backend in global_mouse_whitelist
        if unsafe_string(sdl_backend) == backend
            mouse_can_use_global_state = true
            break
        end
    end

    clipboard_text_data_ptr = Libc.malloc(sizeof(Cchar))
    mouse_last_cursor_ptr = Libc.malloc(sizeof(SDL2.SDL_Cursor))
    mouse_cursors = (
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_ARROW),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_IBEAM),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEALL),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENS),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEWE),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENESW),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENWSE),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_HAND),
        SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_NO)
    )
 
    bd = Ptr{ImGui_ImplSDL2_Data}(Libc.malloc(sizeof(ImGui_ImplSDL2_Data)))
    unsafe_store!(bd, ImGui_ImplSDL2_Data(
        window,
        SDL2.SDL_GetWindowID(window),
        renderer,
        UInt64(0),
        clipboard_text_data_ptr,
        "",
        UInt32(0),
        Int32(0),
        mouse_cursors,
        mouse_last_cursor_ptr,
        Int32(0),
        false,
        false,
        SDL2.SDL_GameController[],
        Int32(0),
        false
    ))
    
    
    io.BackendPlatformUserData = Ptr{Cvoid}(bd)
    sdl_version_ptr = Ptr{SDL2.SDL_version}(Libc.malloc(sizeof(SDL2.SDL_version)))
    SDL2.SDL_GetVersion(sdl_version_ptr)
    sdl_version = unsafe_load(sdl_version_ptr)
    Libc.free(sdl_version_ptr)
    io.BackendPlatformName = pointer("imgui_impl_sdl2 ($(sdl_version.major).$(sdl_version.minor).$(sdl_version.patch), $(sdl_version.major).$(sdl_version.minor).$(sdl_version.patch))")
    io.BackendFlags = unsafe_load(io.BackendFlags) | CImGui.ImGuiBackendFlags_HasMouseCursors       # We can honor GetMouseCursor() values (optional)
    io.BackendFlags = unsafe_load(io.BackendFlags) | CImGui.ImGuiBackendFlags_HasSetMousePos        # We can honor io.WantSetMousePos requests (optional, rarely used)
    
    #Check and store if we are on a SDL backend that supports SDL_GetGlobalMouseState() and SDL_CaptureMouse()
    #("wayland" and "rpi" don't support it, but we chose to use a white-list instead of a black-list)
    bd.MouseCanUseGlobalState = false
    bd.MouseCanUseCapture = false
    @static if SDL_VERSION_ATLEAST(Int32(2),Int32(0),Int32(4)) #&& !defined(__EMSCRIPTEN__) && !defined(__ANDROID__) && !(defined(__APPLE__) && TARGET_OS_IOS) && !defined(__amigaos4__)
        sdl_backend = SDL2.SDL_GetCurrentVideoDriver()
        global_mouse_whitelist = ["windows", "cocoa", "x11", "DIVE", "VMAN"]
        for backend in global_mouse_whitelist
            if unsafe_string(sdl_backend) == backend
                bd.MouseCanUseGlobalState = bd.MouseCanUseCapture = true
            end
        end
    end
    # set clipboard
    platform_io = CImGui.igGetPlatformIO()
    io.SetClipboardTextFn = @cfunction(ImGui_ImplSDL2_SetClipboardText, Int32, (Ptr{Cvoid}, Ptr{Cchar}))
    io.GetClipboardTextFn = @cfunction(ImGui_ImplSDL2_GetClipboardText, Ptr{Cchar}, (Ptr{Cvoid},))
    io.ClipboardUserData = C_NULL
    io.SetPlatformImeDataFn = @cfunction(ImGui_ImplSDL2_PlatformSetImeData, Cvoid, (Ptr{CImGui.ImGuiPlatformImeData},))

    #ifdef __EMSCRIPTEN__
    #platform_io.Platform_OpenInShellFn = [](ImGuiContext*, const char* url) { ImGui_ImplSDL2_EmscriptenOpenURL(url); return true; };
    #elif SDL_HAS_OPEN_URL
    #platform_io.Platform_OpenInShellFn = [](ImGuiContext*, const char* url) { return SDL_OpenURL(url) == 0; };
    #endif

    # Gamepad handling
    #bd.GamepadMode = CImGui.ImGui_ImplSDL2_GamepadMode_AutoFirst
    bd.WantUpdateGamepadsList = true
        
    
    # Set platform dependent data in viewport
    # Our mouse update function expect PlatformHandle to be filled for the main viewport
    main_viewport::Ptr{CImGui.ImGuiViewport} = CImGui.igGetMainViewport()
    handle_ptr = Ptr{UInt32}(Libc.malloc(sizeof(UInt32)))
    unsafe_store!(handle_ptr, bd.WindowID)
    main_viewport.PlatformHandle = handle_ptr
    main_viewport.PlatformHandleRaw = C_NULL
    # SDL_SysWMinfo info;
    # SDL_VERSION(&info.version);
#     if (SDL_GetWindowWMInfo(window, &info))
#     {
# #if defined(SDL_VIDEO_DRIVER_WINDOWS)
#         main_viewport->PlatformHandleRaw = (void*)info.info.win.window;
# #elif defined(__APPLE__) && defined(SDL_VIDEO_DRIVER_COCOA)
#         main_viewport->PlatformHandleRaw = (void*)info.info.cocoa.window;
# #endif
#     }
    
    # From 2.0.5: Set SDL hint to receive mouse click events on window focus, otherwise SDL doesn't emit the event.
    # Without this, when clicking to gain focus, our widgets wouldn't activate even though they showed as hovered.
    # (This is unfortunately a global SDL setting, so enabling it might have a side-effect on your application.
    # It is unlikely to make a difference, but if your app absolutely needs to ignore the initial on-focus click:
    # you can ignore SDL_MOUSEBUTTONDOWN events coming right after a SDL_WINDOWEVENT_FOCUS_GAINED)
    #if def(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH)
    SDL2.SDL_SetHint(SDL2.SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, "1")
    #end
    
    # From 2.0.18: Enable native IME.
    # IMPORTANT: This is used at the time of SDL_CreateWindow() so this will only affects secondary windows, if any.
    # For the main window to be affected, your application needs to call this manually before calling SDL_CreateWindow().
    #if defined(SDL_HINT_IME_SHOW_UI)
    SDL2.SDL_SetHint("SDL_HINT_IME_SHOW_UI", "1")
    #end
    
    # From 2.0.22: Disable auto-capture, this is preventing drag and drop across multiple windows (see #5710)
    #if defined(SDL_HINT_MOUSE_AUTO_CAPTURE)
    SDL2.SDL_SetHint("SDL_HINT_MOUSE_AUTO_CAPTURE", "0")
    #end
    
    return true
end

# // Backend data stored in io.BackendPlatformUserData to allow support for multiple Dear ImGui contexts
# // It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
# // FIXME: multi-context support is not well tested and probably dysfunctional in this backend.
# // FIXME: some shared resources (mouse cursor shape, gamepad) are mishandled when using multi-context.
function ImGui_ImplSDL2_GetBackendData()::Ptr{ImGui_ImplSDL2_Data}
    io = CImGui.GetIO()
    return CImGui.GetCurrentContext() != C_NULL ? convert(Ptr{ImGui_ImplSDL2_Data}, unsafe_load(io.BackendPlatformUserData)) : Ptr{ImGui_ImplSDL2_Data}(C_NULL)
end

# static void ImGui_ImplSDL2_UpdateGamepads()
# {
#     ImGui_ImplSDL2_Data* bd = ImGui_ImplSDL2_GetBackendData();
#     ImGuiIO& io = ImGui::GetIO();

#     // Update list of controller(s) to use
#     if (bd->WantUpdateGamepadsList && bd->GamepadMode != ImGui_ImplSDL2_GamepadMode_Manual)
#     {
#         ImGui_ImplSDL2_CloseGamepads();
#         int joystick_count = SDL_NumJoysticks();
#         for (int n = 0; n < joystick_count; n++)
#             if (SDL_IsGameController(n))
#                 if (SDL_GameController* gamepad = SDL_GameControllerOpen(n))
#                 {
#                     bd->Gamepads.push_back(gamepad);
#                     if (bd->GamepadMode == ImGui_ImplSDL2_GamepadMode_AutoFirst)
#                         break;
#                 }
#         bd->WantUpdateGamepadsList = false;
#     }

#     io.BackendFlags &= ~ImGuiBackendFlags_HasGamepad;
#     if (bd->Gamepads.Size == 0)
#         return;
#     io.BackendFlags |= ImGuiBackendFlags_HasGamepad;

#     // Update gamepad inputs
#     const int thumb_dead_zone = 8000; // SDL_gamecontroller.h suggests using this value.
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadStart,       SDL_CONTROLLER_BUTTON_START);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadBack,        SDL_CONTROLLER_BUTTON_BACK);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadFaceLeft,    SDL_CONTROLLER_BUTTON_X);              // Xbox X, PS Square
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadFaceRight,   SDL_CONTROLLER_BUTTON_B);              // Xbox B, PS Circle
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadFaceUp,      SDL_CONTROLLER_BUTTON_Y);              // Xbox Y, PS Triangle
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadFaceDown,    SDL_CONTROLLER_BUTTON_A);              // Xbox A, PS Cross
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadDpadLeft,    SDL_CONTROLLER_BUTTON_DPAD_LEFT);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadDpadRight,   SDL_CONTROLLER_BUTTON_DPAD_RIGHT);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadDpadUp,      SDL_CONTROLLER_BUTTON_DPAD_UP);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadDpadDown,    SDL_CONTROLLER_BUTTON_DPAD_DOWN);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadL1,          SDL_CONTROLLER_BUTTON_LEFTSHOULDER);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadR1,          SDL_CONTROLLER_BUTTON_RIGHTSHOULDER);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadL2,          SDL_CONTROLLER_AXIS_TRIGGERLEFT,  0.0f, 32767);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadR2,          SDL_CONTROLLER_AXIS_TRIGGERRIGHT, 0.0f, 32767);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadL3,          SDL_CONTROLLER_BUTTON_LEFTSTICK);
#     ImGui_ImplSDL2_UpdateGamepadButton(bd, io, ImGuiKey_GamepadR3,          SDL_CONTROLLER_BUTTON_RIGHTSTICK);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadLStickLeft,  SDL_CONTROLLER_AXIS_LEFTX,  -thumb_dead_zone, -32768);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadLStickRight, SDL_CONTROLLER_AXIS_LEFTX,  +thumb_dead_zone, +32767);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadLStickUp,    SDL_CONTROLLER_AXIS_LEFTY,  -thumb_dead_zone, -32768);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadLStickDown,  SDL_CONTROLLER_AXIS_LEFTY,  +thumb_dead_zone, +32767);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadRStickLeft,  SDL_CONTROLLER_AXIS_RIGHTX, -thumb_dead_zone, -32768);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadRStickRight, SDL_CONTROLLER_AXIS_RIGHTX, +thumb_dead_zone, +32767);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadRStickUp,    SDL_CONTROLLER_AXIS_RIGHTY, -thumb_dead_zone, -32768);
#     ImGui_ImplSDL2_UpdateGamepadAnalog(bd, io, ImGuiKey_GamepadRStickDown,  SDL_CONTROLLER_AXIS_RIGHTY, +thumb_dead_zone, +32767);
# }


function ImGui_ImplSDL2_NewFrame()
    bd = ImGui_ImplSDL2_GetBackendData()
    @assert bd != C_NULL "Did you call ImGui_ImplSDL2_Init()?"
    io = CImGui.GetIO()
    # Setup display size (every frame to accommodate for window resizing)
    w, h = Int32(0), Int32(0)
    display_w, display_h = Int32(0), Int32(0)
    @c SDL2.SDL_GetWindowSize(bd.Window, &w, &h)
    if SDL2.SDL_GetWindowFlags(bd.Window) & SDL2.SDL_WINDOW_MINIMIZED != 0
        w = h = 0
    end
    if bd.Renderer != C_NULL
        @c SDL2.SDL_GetRendererOutputSize(bd.Renderer, &display_w, &display_h)
    #if SDL_HAS_VULKAN
    # else if (SDL_GetWindowFlags(window) & SDL_WINDOW_VULKAN)
    #     SDL_Vulkan_GetDrawableSize(window, &display_w, &display_h);
    #endif
    else
        @c SDL2.SDL_GL_GetDrawableSize(bd.Window, &display_w, &display_h)
    end
    
    io.DisplaySize = ImVec2(Cfloat(w), Cfloat(h))
    if w > 0 && h > 0
        w_scale = Cfloat(display_w / w)
        h_scale = Cfloat(display_h / h)
        io.DisplayFramebufferScale = ImVec2(w_scale, h_scale)
    end

    # Setup time step (we don't use SDL_GetTicks() because it is using millisecond resolution)
    # (Accept SDL_GetPerformanceCounter() not returning a monotonically increasing value. Happens in VMs and Emscripten, see #6189, #6114, #3644)
    frequency = SDL2.SDL_GetPerformanceFrequency()
    current_time = SDL2.SDL_GetPerformanceCounter()
    if current_time <= bd.Time
        current_time = bd.Time + 1
    end
    io.DeltaTime = bd.Time > 0 ? float(current_time - bd.Time) / frequency : 1.0 / 60.0
    bd.Time = current_time

    if bd.MouseLastLeaveFrame != Int32(0) && bd.MouseLastLeaveFrame >= CImGui.GetFrameCount() && bd.MouseButtonsDown == Int32(0)
        bd.MouseWindowID = 0
        bd.MouseLastLeaveFrame = 0
         CImGui.ImGuiIO_AddMousePosEvent(io, -typemax(Float32), -typemax(Float32))
    end

    ImGui_ImplSDL2_UpdateMouseData()
    ImGui_ImplSDL2_UpdateMouseCursor()

    # Update game controllers (if enabled and available)
    #ImGui_ImplSDL2_UpdateGamepads()
end

function ImGui_ImplSDL2_UpdateMouseData()
    bd = ImGui_ImplSDL2_GetBackendData()
    io = CImGui.GetIO()

    # We forward mouse input when hovered or captured (via SDL_MOUSEMOTION) or when focused (below)
    # SDL_CaptureMouse() let the OS know e.g. that our imgui drag outside the SDL window boundaries shouldn't e.g. trigger other operations outside
    SDL2.SDL_CaptureMouse(bd.MouseButtonsDown != 0 ? SDL2.SDL_TRUE : SDL2.SDL_FALSE)
    focused_window = SDL2.SDL_GetKeyboardFocus()
    is_app_focused = bd.Window == focused_window ? true : false

    if is_app_focused
        # (Optional) Set OS mouse position from Dear ImGui if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
        if unsafe_load(io.WantSetMousePos)
            SDL2.SDL_WarpMouseInWindow(bd.Window, Int32(io.MousePos.x), Int32(io.MousePos.y))
        end

        # (Optional) Fallback to provide mouse position when focused (SDL_MOUSEMOTION already provides this when hovered or captured)
        if bd.MouseCanUseGlobalState && bd.MouseButtonsDown == 0
            window_x, window_y, mouse_x_global, mouse_y_global = Int32(0), Int32(0), Int32(0), Int32(0)
            @c SDL2.SDL_GetGlobalMouseState(&mouse_x_global, &mouse_y_global)
            @c SDL2.SDL_GetWindowPosition(bd.Window, &window_x, &window_y)
             CImGui.ImGuiIO_AddMousePosEvent(io, Cfloat(mouse_x_global - window_x), Cfloat(mouse_y_global - window_y))
        end
    end
end

function ImGui_ImplSDL2_UpdateMouseCursor()
    io::Ptr{ CImGui.ImGuiIO} = CImGui.GetIO()
    # if (unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_NoMouseCursorChange == ImGuiConfigFlags_NoMouseCursorChange) ||
    #     return nothing
    # end
    bd = ImGui_ImplSDL2_GetBackendData()

    imgui_cursor = CImGui.GetMouseCursor()
    if imgui_cursor ==  CImGui.ImGuiMouseCursor_None || unsafe_load(io.MouseDrawCursor)
        # Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        SDL2.SDL_ShowCursor(SDL2.SDL_FALSE)
    else
        # Show OS mouse cursor
        mouse_cursors = bd.MouseCursors
        expected_cursor = mouse_cursors[imgui_cursor+1] != C_NULL ? mouse_cursors[imgui_cursor+1] : mouse_cursors[ CImGui.ImGuiMouseCursor_Arrow+1]
        if bd.MouseLastCursor != expected_cursor
            SDL2.SDL_SetCursor(expected_cursor) # SDL function doesn't have an early out (see #6113)
            bd.MouseLastCursor = expected_cursor
        end
        SDL2.SDL_ShowCursor(SDL2.SDL_TRUE)
    end
end

function ImGui_ImplSDL2_GetViewportForWindowID(window_id::UInt32)::Ptr{CImGui.ImGuiViewport}
    bd = ImGui_ImplSDL2_GetBackendData()
    return (window_id == bd.WindowID) ? CImGui.igGetMainViewport() : Ptr{CImGui.ImGuiViewport}(C_NULL)
end

# You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
# - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
# - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
# Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
# If you have multiple SDL events and some of them are not meant to be used by dear imgui, you may need to filter events based on their windowID field.
function ImGui_ImplSDL2_ProcessEvent(event::SDL2.SDL_Event)::Bool
    io = CImGui.GetIO()
    bd = ImGui_ImplSDL2_GetBackendData()
    if bd == C_NULL
        error("ImGui_ImplSDL2_GetBackendData() returned C_NULL")
        return false
    end

    if event.type == SDL2.SDL_MOUSEMOTION
        if ImGui_ImplSDL2_GetViewportForWindowID(event.motion.windowID) == Ptr{CImGui.ImGuiViewport}(C_NULL)
            return false
        end
        mouse_pos = ImVec2(float(event.motion.x), float(event.motion.y))
        CImGui.ImGuiIO_AddMouseSourceEvent(io, event.motion.which == SDL2.SDL_TOUCH_MOUSEID ? CImGui.ImGuiMouseSource_TouchScreen : CImGui.ImGuiMouseSource_Mouse)
        CImGui.ImGuiIO_AddMousePosEvent(io, mouse_pos.x, mouse_pos.y)
        return true
    elseif event.type == SDL2.SDL_MOUSEWHEEL
        if ImGui_ImplSDL2_GetViewportForWindowID(event.wheel.windowID) == Ptr{CImGui.ImGuiViewport}(C_NULL)
            return false
        end
        wheel_x = SDL_VERSION_ATLEAST(Int32(2), Int32(0), Int32(18)) ? -event.wheel.preciseX : -(Cfloat(event.wheel.x))
        wheel_y = SDL_VERSION_ATLEAST(Int32(2), Int32(0), Int32(18)) ? event.wheel.preciseY : Cfloat(event.wheel.y)
        # if __EMSCRIPTEN__
        # wheel_x /= 100.0f 
        # end
        CImGui.ImGuiIO_AddMouseSourceEvent(io, event.wheel.which == SDL2.SDL_TOUCH_MOUSEID ? CImGui.ImGuiMouseSource_TouchScreen : CImGui.ImGuiMouseSource_Mouse)
         CImGui.ImGuiIO_AddMouseWheelEvent(io, wheel_x, wheel_y)
        return true
    elseif event.type == SDL2.SDL_MOUSEBUTTONDOWN || event.type == SDL2.SDL_MOUSEBUTTONUP
        if ImGui_ImplSDL2_GetViewportForWindowID(event.button.windowID) == Ptr{CImGui.ImGuiViewport}(C_NULL)
            return false
        end
        mouse_button = -1
        if event.button.button == SDL2.SDL_BUTTON_LEFT
            mouse_button = 0
        elseif event.button.button == SDL2.SDL_BUTTON_RIGHT
            mouse_button = 1
        elseif event.button.button == SDL2.SDL_BUTTON_MIDDLE
            mouse_button = 2
        elseif event.button.button == SDL2.SDL_BUTTON_X1
            mouse_button = 3
        elseif event.button.button == SDL2.SDL_BUTTON_X2
            mouse_button = 4
        end
        if mouse_button == -1
            return false
        end
        
        CImGui.ImGuiIO_AddMouseSourceEvent(io, event.button.which == SDL2.SDL_TOUCH_MOUSEID ? CImGui.ImGuiMouseSource_TouchScreen : CImGui.ImGuiMouseSource_Mouse)
        CImGui.ImGuiIO_AddMouseButtonEvent(io, mouse_button, event.type == SDL2.SDL_MOUSEBUTTONDOWN)
        bd.MouseButtonsDown = event.type == SDL2.SDL_MOUSEBUTTONDOWN ? bd.MouseButtonsDown | (1 << mouse_button) : bd.MouseButtonsDown & ~(1 << mouse_button)
        return true
    elseif event.type == SDL2.SDL_TEXTINPUT
        if ImGui_ImplSDL2_GetViewportForWindowID(event.text.windowID) == Ptr{CImGui.ImGuiViewport}(C_NULL)
            return false
        end
        CImGui.ImGuiIO_AddInputCharactersUTF8(io, Ref(event.text.text))
        return true
    elseif event.type == SDL2.SDL_KEYDOWN || event.type == SDL2.SDL_KEYUP
        if ImGui_ImplSDL2_GetViewportForWindowID(event.text.windowID) == Ptr{CImGui.ImGuiViewport}(C_NULL)
            return false
        end
        ImGui_ImplSDL2_UpdateKeyModifiers(SDL2.SDL_Keymod(event.key.keysym.mod))
        key = ImGui_ImplSDL2_KeycodeToImGuiKey(event.key.keysym.sym)
        CImGui.ImGuiIO_AddKeyEvent(io, key, event.type == SDL2.SDL_KEYDOWN)
        CImGui.ImGuiIO_SetKeyEventNativeData(io, key, event.key.keysym.sym, event.key.keysym.scancode, event.key.keysym.scancode) # To support legacy indexing (<1.87 user code). Legacy backend uses SDL2.SDLK_*** as indices to IsKeyXXX() functions.
        return true
    elseif event.type == SDL2.SDL_WINDOWEVENT
        if ImGui_ImplSDL2_GetViewportForWindowID(event.text.windowID) == Ptr{CImGui.ImGuiViewport}(C_NULL)
            return false
        end
        # - When capturing mouse, SDL will send a bunch of conflicting LEAVE/ENTER event on every mouse move, but the final ENTER tends to be right.
        # - However we won't get a correct LEAVE event for a captured window.
        # - In some cases, when detaching a window from main viewport SDL may send SDL_WINDOWEVENT_ENTER one frame too late,
        #   causing SDL_WINDOWEVENT_LEAVE on previous frame to interrupt drag operation by clear mouse position. This is why
        #   we delay process the SDL_WINDOWEVENT_LEAVE events by one frame. See issue #5012 for details.
        window_event = UInt32(event.window.event)
        if window_event == SDL2.SDL_WINDOWEVENT_ENTER
            bd.MouseWindowID = event.window.windowID
            bd.MouseLastLeaveFrame = 0
        end
        if window_event == SDL2.SDL_WINDOWEVENT_LEAVE
            bd.MouseLastLeaveFrame = CImGui.GetFrameCount() + 1
        end
        if window_event == SDL2.SDL_WINDOWEVENT_FOCUS_GAINED
             CImGui.ImGuiIO_AddFocusEvent(io, true)
        elseif event.window.event == SDL2.SDL_WINDOWEVENT_FOCUS_LOST
             CImGui.ImGuiIO_AddFocusEvent(io, false)
        end
        return true
    elseif event.type == SDL2.SDL_CONTROLLERDEVICEADDED || event.type == SDL2.SDL_CONTROLLERDEVICEREMOVED
        bd.WantUpdateGamepadsList = true
        return true
    end
    return false
end

function ImGui_ImplSDL2_UpdateKeyModifiers(sdl_key_mods)
    io = CImGui.GetIO()
     CImGui.ImGuiIO_AddKeyEvent(io, CImGui.ImGuiMod_Ctrl, (sdl_key_mods & SDL2.KMOD_CTRL) != 0)
     CImGui.ImGuiIO_AddKeyEvent(io, CImGui.ImGuiMod_Shift, (sdl_key_mods & SDL2.KMOD_SHIFT) != 0)
     CImGui.ImGuiIO_AddKeyEvent(io, CImGui.ImGuiMod_Alt, (sdl_key_mods & SDL2.KMOD_ALT) != 0)
     CImGui.ImGuiIO_AddKeyEvent(io, CImGui.ImGuiMod_Super, (sdl_key_mods & SDL2.KMOD_GUI) != 0)
end

function ImGui_ImplSDL2_KeycodeToImGuiKey(keycode)
    return get(keycode_dict, keycode, CImGui.ImGuiKey_None)
end


function ImGui_ImplSDL2_InitForVulkan(window)
    # #if !SDL_HAS_VULKAN
    #     IM_ASSERT(0 && "Unsupported");
    # #endif
    return ImGui_ImplSDL2_Init(window, nothing)
end

function ImGui_ImplSDL2_InitForD3D(window)
    # #if !defined(_WIN32)
    #     IM_ASSERT(0 && "Unsupported");
    # #endif
    return ImGui_ImplSDL2_Init(window, nothing)
end

function ImGui_ImplSDL2_InitForMetal(window)
    return ImGui_ImplSDL2_Init(window, nothing)
end

function ImGui_ImplSDL2_InitForOther(window)
    return ImGui_ImplSDL2_Init(window, nothing)
end

keycode_dict = Dict(
        UInt32(SDL2.LibSDL2.SDLK_TAB) => CImGui.ImGuiKey_Tab,
        UInt32(SDL2.LibSDL2.SDLK_LEFT) => CImGui.ImGuiKey_LeftArrow,
        UInt32(SDL2.LibSDL2.SDLK_RIGHT) => CImGui.ImGuiKey_RightArrow,
        UInt32(SDL2.LibSDL2.SDLK_UP) => CImGui.ImGuiKey_UpArrow,
        UInt32(SDL2.LibSDL2.SDLK_DOWN) => CImGui.ImGuiKey_DownArrow,
        UInt32(SDL2.LibSDL2.SDLK_PAGEUP) => CImGui.ImGuiKey_PageUp,
        UInt32(SDL2.LibSDL2.SDLK_PAGEDOWN) => CImGui.ImGuiKey_PageDown,
        UInt32(SDL2.LibSDL2.SDLK_HOME) => CImGui.ImGuiKey_Home,
        UInt32(SDL2.LibSDL2.SDLK_END) => CImGui.ImGuiKey_End,
        UInt32(SDL2.LibSDL2.SDLK_INSERT) => CImGui.ImGuiKey_Insert,
        UInt32(SDL2.LibSDL2.SDLK_DELETE) => CImGui.ImGuiKey_Delete,
        UInt32(SDL2.LibSDL2.SDLK_BACKSPACE) => CImGui.ImGuiKey_Backspace,
        UInt32(SDL2.LibSDL2.SDLK_SPACE) => CImGui.ImGuiKey_Space,
        UInt32(SDL2.LibSDL2.SDLK_RETURN) => CImGui.ImGuiKey_Enter,
        UInt32(SDL2.LibSDL2.SDLK_ESCAPE) => CImGui.ImGuiKey_Escape,
        UInt32(SDL2.LibSDL2.SDLK_QUOTE) => CImGui.ImGuiKey_Apostrophe,
        UInt32(SDL2.LibSDL2.SDLK_COMMA) => CImGui.ImGuiKey_Comma,
        UInt32(SDL2.LibSDL2.SDLK_MINUS) => CImGui.ImGuiKey_Minus,
        UInt32(SDL2.LibSDL2.SDLK_PERIOD) => CImGui.ImGuiKey_Period,
        UInt32(SDL2.LibSDL2.SDLK_SLASH) => CImGui.ImGuiKey_Slash,
        UInt32(SDL2.LibSDL2.SDLK_SEMICOLON) => CImGui.ImGuiKey_Semicolon,
        UInt32(SDL2.LibSDL2.SDLK_EQUALS) => CImGui.ImGuiKey_Equal,
        UInt32(SDL2.LibSDL2.SDLK_LEFTBRACKET) => CImGui.ImGuiKey_LeftBracket,
        UInt32(SDL2.LibSDL2.SDLK_BACKSLASH) => CImGui.ImGuiKey_Backslash,
        UInt32(SDL2.LibSDL2.SDLK_RIGHTBRACKET) => CImGui.ImGuiKey_RightBracket,
        UInt32(SDL2.LibSDL2.SDLK_BACKQUOTE) => CImGui.ImGuiKey_GraveAccent,
        UInt32(SDL2.LibSDL2.SDLK_CAPSLOCK) => CImGui.ImGuiKey_CapsLock,
        UInt32(SDL2.LibSDL2.SDLK_SCROLLLOCK) => CImGui.ImGuiKey_ScrollLock,
        UInt32(SDL2.LibSDL2.SDLK_NUMLOCKCLEAR) => CImGui.ImGuiKey_NumLock,
        UInt32(SDL2.LibSDL2.SDLK_PRINTSCREEN) => CImGui.ImGuiKey_PrintScreen,
        UInt32(SDL2.LibSDL2.SDLK_PAUSE) => CImGui.ImGuiKey_Pause,
        UInt32(SDL2.LibSDL2.SDLK_KP_0) => CImGui.ImGuiKey_Keypad0,
        UInt32(SDL2.LibSDL2.SDLK_KP_1) => CImGui.ImGuiKey_Keypad1,
        UInt32(SDL2.LibSDL2.SDLK_KP_2) => CImGui.ImGuiKey_Keypad2,
        UInt32(SDL2.LibSDL2.SDLK_KP_3) => CImGui.ImGuiKey_Keypad3,
        UInt32(SDL2.LibSDL2.SDLK_KP_4) => CImGui.ImGuiKey_Keypad4,
        UInt32(SDL2.LibSDL2.SDLK_KP_5) => CImGui.ImGuiKey_Keypad5,
        UInt32(SDL2.LibSDL2.SDLK_KP_6) => CImGui.ImGuiKey_Keypad6,
        UInt32(SDL2.LibSDL2.SDLK_KP_7) => CImGui.ImGuiKey_Keypad7,
        UInt32(SDL2.LibSDL2.SDLK_KP_8) => CImGui.ImGuiKey_Keypad8,
        UInt32(SDL2.LibSDL2.SDLK_KP_9) => CImGui.ImGuiKey_Keypad9,
        UInt32(SDL2.LibSDL2.SDLK_KP_PERIOD) => CImGui.ImGuiKey_KeypadDecimal,
        UInt32(SDL2.LibSDL2.SDLK_KP_DIVIDE) => CImGui.ImGuiKey_KeypadDivide,
        UInt32(SDL2.LibSDL2.SDLK_KP_MULTIPLY) => CImGui.ImGuiKey_KeypadMultiply,
        UInt32(SDL2.LibSDL2.SDLK_KP_MINUS) => CImGui.ImGuiKey_KeypadSubtract,
        UInt32(SDL2.LibSDL2.SDLK_KP_PLUS) => CImGui.ImGuiKey_KeypadAdd,
        UInt32(SDL2.LibSDL2.SDLK_KP_ENTER) => CImGui.ImGuiKey_KeypadEnter,
        UInt32(SDL2.LibSDL2.SDLK_KP_EQUALS) => CImGui.ImGuiKey_KeypadEqual,
        UInt32(SDL2.LibSDL2.SDLK_LCTRL) => CImGui.ImGuiKey_LeftCtrl,
        UInt32(SDL2.LibSDL2.SDLK_LSHIFT) => CImGui.ImGuiKey_LeftShift,
        UInt32(SDL2.LibSDL2.SDLK_LALT) => CImGui.ImGuiKey_LeftAlt,
        UInt32(SDL2.LibSDL2.SDLK_LGUI) => CImGui.ImGuiKey_LeftSuper,
        UInt32(SDL2.LibSDL2.SDLK_RCTRL) => CImGui.ImGuiKey_RightCtrl,
        UInt32(SDL2.LibSDL2.SDLK_RSHIFT) => CImGui.ImGuiKey_RightShift,
        UInt32(SDL2.LibSDL2.SDLK_RALT) => CImGui.ImGuiKey_RightAlt,
        UInt32(SDL2.LibSDL2.SDLK_RGUI) => CImGui.ImGuiKey_RightSuper,
        UInt32(SDL2.LibSDL2.SDLK_APPLICATION) => CImGui.ImGuiKey_Menu,
        UInt32(SDL2.LibSDL2.SDLK_0) => CImGui.ImGuiKey_0,
        UInt32(SDL2.LibSDL2.SDLK_1) => CImGui.ImGuiKey_1,
        UInt32(SDL2.LibSDL2.SDLK_2) => CImGui.ImGuiKey_2,
        UInt32(SDL2.LibSDL2.SDLK_3) => CImGui.ImGuiKey_3,
        UInt32(SDL2.LibSDL2.SDLK_4) => CImGui.ImGuiKey_4,
        UInt32(SDL2.LibSDL2.SDLK_5) => CImGui.ImGuiKey_5,
        UInt32(SDL2.LibSDL2.SDLK_6) => CImGui.ImGuiKey_6,
        UInt32(SDL2.LibSDL2.SDLK_7) => CImGui.ImGuiKey_7,
        UInt32(SDL2.LibSDL2.SDLK_8) => CImGui.ImGuiKey_8,
        UInt32(SDL2.LibSDL2.SDLK_9) => CImGui.ImGuiKey_9,
        UInt32(SDL2.LibSDL2.SDLK_a) => CImGui.ImGuiKey_A,
        UInt32(SDL2.LibSDL2.SDLK_b) => CImGui.ImGuiKey_B,
        UInt32(SDL2.LibSDL2.SDLK_c) => CImGui.ImGuiKey_C,
        UInt32(SDL2.LibSDL2.SDLK_d) => CImGui.ImGuiKey_D,
        UInt32(SDL2.LibSDL2.SDLK_e) => CImGui.ImGuiKey_E,
        UInt32(SDL2.LibSDL2.SDLK_f) => CImGui.ImGuiKey_F,
        UInt32(SDL2.LibSDL2.SDLK_g) => CImGui.ImGuiKey_G,
        UInt32(SDL2.LibSDL2.SDLK_h) => CImGui.ImGuiKey_H,
        UInt32(SDL2.LibSDL2.SDLK_i) => CImGui.ImGuiKey_I,
        UInt32(SDL2.LibSDL2.SDLK_j) => CImGui.ImGuiKey_J,
        UInt32(SDL2.LibSDL2.SDLK_k) => CImGui.ImGuiKey_K,
        UInt32(SDL2.LibSDL2.SDLK_l) => CImGui.ImGuiKey_L,
        UInt32(SDL2.LibSDL2.SDLK_m) => CImGui.ImGuiKey_M,
        UInt32(SDL2.LibSDL2.SDLK_n) => CImGui.ImGuiKey_N,
        UInt32(SDL2.LibSDL2.SDLK_o) => CImGui.ImGuiKey_O,
        UInt32(SDL2.LibSDL2.SDLK_p) => CImGui.ImGuiKey_P,
        UInt32(SDL2.LibSDL2.SDLK_q) => CImGui.ImGuiKey_Q,
        UInt32(SDL2.LibSDL2.SDLK_r) => CImGui.ImGuiKey_R,
        UInt32(SDL2.LibSDL2.SDLK_s) => CImGui.ImGuiKey_S,
        UInt32(SDL2.LibSDL2.SDLK_t) => CImGui.ImGuiKey_T,
        UInt32(SDL2.LibSDL2.SDLK_u) => CImGui.ImGuiKey_U,
        UInt32(SDL2.LibSDL2.SDLK_v) => CImGui.ImGuiKey_V,
        UInt32(SDL2.LibSDL2.SDLK_w) => CImGui.ImGuiKey_W,
        UInt32(SDL2.LibSDL2.SDLK_x) => CImGui.ImGuiKey_X,
        UInt32(SDL2.LibSDL2.SDLK_y) => CImGui.ImGuiKey_Y,
        UInt32(SDL2.LibSDL2.SDLK_z) => CImGui.ImGuiKey_Z,
        UInt32(SDL2.LibSDL2.SDLK_F1) => CImGui.ImGuiKey_F1,
        UInt32(SDL2.LibSDL2.SDLK_F2) => CImGui.ImGuiKey_F2,
        UInt32(SDL2.LibSDL2.SDLK_F3) => CImGui.ImGuiKey_F3,
        UInt32(SDL2.LibSDL2.SDLK_F4) => CImGui.ImGuiKey_F4,
        UInt32(SDL2.LibSDL2.SDLK_F5) => CImGui.ImGuiKey_F5,
        UInt32(SDL2.LibSDL2.SDLK_F6) => CImGui.ImGuiKey_F6,
        UInt32(SDL2.LibSDL2.SDLK_F7) => CImGui.ImGuiKey_F7,
        UInt32(SDL2.LibSDL2.SDLK_F8) => CImGui.ImGuiKey_F8,
        UInt32(SDL2.LibSDL2.SDLK_F9) => CImGui.ImGuiKey_F9,
        UInt32(SDL2.LibSDL2.SDLK_F10) => CImGui.ImGuiKey_F10,
        UInt32(SDL2.LibSDL2.SDLK_F11) => CImGui.ImGuiKey_F11,
        UInt32(SDL2.LibSDL2.SDLK_F12) => CImGui.ImGuiKey_F12,
        # SDL2.LibSDL2.SDLK_F13 => CImGui.ImGuiKey_F13,
        # SDL2.LibSDL2.SDLK_F14 => CImGui.ImGuiKey_F14,
        # SDL2.LibSDL2.SDLK_F15 => CImGui.ImGuiKey_F15,
        # SDL2.LibSDL2.SDLK_F16 => CImGui.ImGuiKey_F16,
        # SDL2.LibSDL2.SDLK_F17 => CImGui.ImGuiKey_F17,
        # SDL2.LibSDL2.SDLK_F18 => CImGui.ImGuiKey_F18,
        # SDL2.LibSDL2.SDLK_F19 => CImGui.ImGuiKey_F19,
        # SDL2.LibSDL2.SDLK_F20 => CImGui.ImGuiKey_F20,
        # SDL2.LibSDL2.SDLK_F21 => CImGui.ImGuiKey_F21,
        # SDL2.LibSDL2.SDLK_F22 => CImGui.ImGuiKey_F22,
        # SDL2.LibSDL2.SDLK_F23 => CImGui.ImGuiKey_F23,
        # SDL2.LibSDL2.SDLK_F24 => CImGui.ImGuiKey_F24,
        # SDL2.LibSDL2.SDLK_AC_BACK => CImGui.ImGuiKey_AppBack,
        # SDL2.LibSDL2.SDLK_AC_FORWARD => CImGui.ImGuiKey_AppForward
    )