Base.@kwdef mutable struct ImGui_ImplSDL2_Data
    Window::Ptr{Any}
    Renderer::Ptr{Any}
    Time::UInt64
    MouseWindowID::UInt32
    MouseButtonsDown::Cint
    MouseCursors::Vector{Ptr{Any}}
    LastMouseCursor::Ptr{Any}
    PendingMouseLeaveFrame::Cint
    ClipboardTextData::Ptr{Cchar}
    MouseCanUseGlobalState::Bool
end

function ImGui_ImplSDL2_InitForOpenGL(window, sdl_gl_context)
    #IM_UNUSED(sdl_gl_context); // Viewport branch will need this.
    return ImGui_ImplSDL2_Init(window, Ptr{Cvoid}(C_NULL));
end

function ImGui_ImplSDL2_Init(window, renderer)
    io = CImGui.GetIO()
    @assert unsafe_load(io.BackendPlatformUserData) == C_NULL

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

    bd = ImGui_ImplSDL2_Data(
        window,
        renderer,
        0,
        0,
        0,
        fill(Ptr{Any}(C_NULL), Int(9)),
        Ptr{Cvoid}(C_NULL),
        0,
        Ptr{Cchar}(C_NULL),
        mouse_can_use_global_state
    )

    io.BackendPlatformUserData = pointer_from_objref(bd)
    io.BackendPlatformName = pointer("imgui_impl_sdl2")
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_HasMouseCursors       # We can honor GetMouseCursor() values (optional)
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_HasSetMousePos        # We can honor io.WantSetMousePos requests (optional, rarely used)

    # set clipboard
    # io.SetClipboardTextFn = pointer(ImGui_ImplSDL2_SetClipboardText)
    # io.GetClipboardTextFn = pointer(ImGui_ImplSDL2_GetClipboardText)
    # io.ClipboardUserData = nothing
    # io.SetPlatformImeDataFn = ImGui_ImplSDL2_SetPlatformImeData

    # Load mouse cursors
    bd.MouseCursors[ImGuiMouseCursor_Arrow+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_ARROW)
    bd.MouseCursors[ImGuiMouseCursor_TextInput+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_IBEAM)
    bd.MouseCursors[ImGuiMouseCursor_ResizeAll+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEALL)
    bd.MouseCursors[ImGuiMouseCursor_ResizeNS+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENS)
    bd.MouseCursors[ImGuiMouseCursor_ResizeEW+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEWE)
    bd.MouseCursors[ImGuiMouseCursor_ResizeNESW+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENESW)
    bd.MouseCursors[ImGuiMouseCursor_ResizeNWSE+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENWSE)
    bd.MouseCursors[ImGuiMouseCursor_Hand+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_HAND)
    bd.MouseCursors[ImGuiMouseCursor_NotAllowed+1] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_NO)

    # Set platform dependent data in viewport
    # Our mouse update function expect PlatformHandle to be filled for the main viewport
    main_viewport = igGetMainViewport()
    main_viewport.PlatformHandleRaw = C_NULL
    # info = SDL_SysWMinfo()
    # SDL_VERSION(info.version)
    # if SDL_GetWindowWMInfo(window, info)
    #     if Sys.iswindows()
    #         main_viewport.PlatformHandleRaw = info.info.win.window
    #     elseif Sys.isapple()
    #         main_viewport.PlatformHandleRaw = info.info.cocoa.window
    #     end
    # end

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


function ImGui_ImplSDL2_SetClipboardText(text)
    SDL2.SDL_SetClipboardText(text)
end

function ImGui_ImplSDL2_GetClipboardText()
    bd = ImGui_ImplSDL2_GetBackendData()
    if (bd.ClipboardTextData != C_NULL && bd.ClipboardTextData !== nothing)
        SDL2.SDL_free(bd.ClipboardTextData)
    end
    bd.ClipboardTextData = SDL_GetClipboardText()
    return bd.ClipboardTextData
end


# // Backend data stored in io.BackendPlatformUserData to allow support for multiple Dear ImGui contexts
# // It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
# // FIXME: multi-context support is not well tested and probably dysfunctional in this backend.
# // FIXME: some shared resources (mouse cursor shape, gamepad) are mishandled when using multi-context.
function ImGui_ImplSDL2_GetBackendData()
    
    io::Ptr{ImGuiIO} = CImGui.GetIO()
    bep = unsafe_load(io.BackendPlatformUserData)::Ptr{Cvoid}
    GC.@preserve bep = unsafe_pointer_to_objref(bep)
    return CImGui.GetCurrentContext() != C_NULL ? bep : C_NULL
end


function ImGui_ImplSDL2_NewFrame()
    @GC.preserve bd = ImGui_ImplSDL2_GetBackendData()
    @assert bd != C_NULL# && "Did you call ImGui_ImplSDL2_Init()?"
    io = CImGui.GetIO()
    # Setup display size (every frame to accommodate for window resizing)
    w, h = Cint(0), Cint(0)
    display_w, display_h = Cint(0), Cint(0)
    @c SDL2.SDL_GetWindowSize(bd.Window, &w, &h)
    if SDL2.SDL_GetWindowFlags(bd.Window) & SDL2.SDL_WINDOW_MINIMIZED != 0
        w = h = 0
    end
    if bd.Renderer != C_NULL
        @c SDL2.SDL_GetRendererOutputSize(bd.Renderer, &display_w, &display_h)
        #SDL2.SDL_GetRendererOutputSize(bd.Renderer, 1280, 720)
    else
        @c SDL2.SDL_GL_GetDrawableSize(bd.Window, &display_w, &display_h)
        #SDL2.SDL_GL_GetDrawableSize(bd.Window, 1280, 720)
    end
    #io.DisplaySize = ImVec2(Cfloat(w), Cfloat(h))
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

    # FLT_MAX = igGET_FLT_MAX()

    # #if bd.PendingMouseLeaveFrame && bd.PendingMouseLeaveFrame >= CImGui.GetFrameCount() && bd.MouseButtonsDown == 0
    # if bd.PendingMouseLeaveFrame >= CImGui.GetFrameCount() && bd.MouseButtonsDown == 0
    #     bd.MouseWindowID = 0
    #     bd.PendingMouseLeaveFrame = 0
    #     ImGuiIO_AddMousePosEvent(io, -FLT_MAX, -FLT_MAX)
    # end

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
            SDL2.SDL_WarpMouseInWindow(bd.Window, Cint(io.MousePos.x), Cint(io.MousePos.y))
        end

        # (Optional) Fallback to provide mouse position when focused (SDL_MOUSEMOTION already provides this when hovered or captured)
        if bd.MouseCanUseGlobalState && bd.MouseButtonsDown == 0
            window_x, window_y, mouse_x_global, mouse_y_global = Cint(0), Cint(0), Cint(0), Cint(0)
            @c SDL2.SDL_GetGlobalMouseState(&mouse_x_global, &mouse_y_global)
            @c SDL2.SDL_GetWindowPosition(bd.Window, &window_x, &window_y)
            ImGuiIO_AddMousePosEvent(io, Cfloat(mouse_x_global - window_x), Cfloat(mouse_y_global - window_y))
        end
    end
end

function ImGui_ImplSDL2_UpdateMouseCursor()
    io::Ptr{ImGuiIO} = CImGui.GetIO()
    # if (unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_NoMouseCursorChange == ImGuiConfigFlags_NoMouseCursorChange) ||
    #     return nothing
    # end
    bd = ImGui_ImplSDL2_GetBackendData()

    imgui_cursor = CImGui.GetMouseCursor()
    if imgui_cursor == ImGuiMouseCursor_None || unsafe_load(io.MouseDrawCursor)
        # Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        SDL2.SDL_ShowCursor(SDL2.SDL_FALSE)
    else
        # Show OS mouse cursor
        expected_cursor = bd.MouseCursors[imgui_cursor+1] != C_NULL ? bd.MouseCursors[imgui_cursor+1] : bd.MouseCursors[ImGuiMouseCursor_Arrow+1]
        if bd.LastMouseCursor != expected_cursor
            SDL2.SDL_SetCursor(expected_cursor) # SDL function doesn't have an early out (see #6113)
            bd.LastMouseCursor = expected_cursor
        end
        SDL2.SDL_ShowCursor(SDL2.SDL_TRUE)
    end
end

function ImGui_ImplSDL2_InitForSDLRenderer(window, renderer)
    return ImGui_ImplSDL2_Init(window, renderer)
end

######################################################################################## Untested

function ImGui_ImplSDL2_ProcessEvent(event)
    io = CImGui.GetIO()
    bd = ImGui_ImplSDL2_GetBackendData()

    if event.type == SDL2.SDL_MOUSEMOTION
        mouse_pos = ImVec2(float(event.motion.x), float(event.motion.y))
        #io.AddMouseSourceEvent(event.motion.which == SDL2.SDL_TOUCH_MOUSEID ? ImGuiMouseSource_TouchScreen : ImGuiMouseSource_Mouse)
        ImGuiIO_AddMousePosEvent(io, mouse_pos.x, mouse_pos.y)
        return true
    elseif event.type == SDL2.SDL_MOUSEWHEEL
        wheel_x = sdlVersion >= 2018 ? -event.wheel.preciseX : -(Cfloat(event.wheel.x))
        wheel_y = sdlVersion >= 2018 ? event.wheel.preciseY : Cfloat(event.wheel.y)
        # if __EMSCRIPTEN__
        # wheel_x /= 100.0f 
        # end
        #io.AddMouseSourceEvent(event.wheel.which == SDL2.SDL_TOUCH_MOUSEID ? ImGuiMouseSource_TouchScreen : ImGuiMouseSource_Mouse)
        ImGuiIO_AddMouseWheelEvent(io, wheel_x, wheel_y)
        return true
    elseif event.type == SDL2.SDL_MOUSEBUTTONDOWN || event.type == SDL2.SDL_MOUSEBUTTONUP
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
        #ImGuiIO_AddMouseSourceEvent(io, event.button.which == SDL2.SDL_TOUCH_MOUSEID ? ImGuiMouseSource_TouchScreen : ImGuiMouseSource_Mouse)
        ImGuiIO_AddMouseButtonEvent(io, mouse_button, event.type == SDL2.SDL_MOUSEBUTTONDOWN)
        bd.MouseButtonsDown = event.type == SDL2.SDL_MOUSEBUTTONDOWN ? bd.MouseButtonsDown | (1 << mouse_button) : bd.MouseButtonsDown & ~(1 << mouse_button)
        return true
    elseif event.type == SDL2.SDL_TEXTINPUT
        ImGuiIO_AddInputCharactersUTF8(io, event.text.text)
        return true
    elseif event.type == SDL2.SDL_KEYDOWN || event.type == SDL2.SDL_KEYUP
        ImGui_ImplSDL2_UpdateKeyModifiers(SDL2.SDL_Keymod(event.key.keysym.mod))
        key = ImGui_ImplSDL2_KeycodeToImGuiKey(event.key.keysym.sym)
        ImGuiIO_AddKeyEvent(io, key, event.type == SDL2.SDL_KEYDOWN)
        ImGuiIO_SetKeyEventNativeData(io, key, event.key.keysym.sym, event.key.keysym.scancode, event.key.keysym.scancode) # To support legacy indexing (<1.87 user code). Legacy backend uses SDL2.SDLK_*** as indices to IsKeyXXX() functions.
        return true
    elseif event.type == SDL2.SDL_WINDOWEVENT
        window_event = event.window.event
        if window_event == SDL2.SDL_WINDOWEVENT_ENTER
            bd.MouseWindowID = event.window.windowID
            bd.PendingMouseLeaveFrame = 0
        end
        if window_event == SDL2.SDL_WINDOWEVENT_LEAVE
            bd.PendingMouseLeaveFrame = CImGui.GetFrameCount() + 1
        end
        if window_event == SDL2.SDL_WINDOWEVENT_FOCUS_GAINED
            ImGuiIO_AddFocusEvent(io, true)
        elseif event.window.event == SDL2.SDL_WINDOWEVENT_FOCUS_LOST
            ImGuiIO_AddFocusEvent(io, false)
        end
        return true
    end
    return false
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
