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
    

    println(io.BackendPlatformUserData)
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

    # Setup backend capabilities flags
    # bd = pointer(ImGui_ImplSDL2_Data[ImGui_ImplSDL2_Data(
    #     window,
    #     renderer,
    #     0,
    #     0,
    #     0,
    #     fill(Ptr{Any}(C_NULL), Int(9)),
    #     Ptr{Cvoid}(C_NULL),
    #     0,
    #     Ptr{Cchar}(C_NULL),
    #     mouse_can_use_global_state
    # )])
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
    println("io.BackendPlatformUserData: ", unsafe_load(io.BackendPlatformUserData)::Ptr{Cvoid})
    bep = unsafe_load(io.BackendPlatformUserData)::Ptr{Cvoid}
    GC.@preserve bep = unsafe_pointer_to_objref(bep)
    # println(ctx)
    # println(unsafe_load(CImGui.GetIO().BackendPlatformUserData))
    return CImGui.GetCurrentContext() != C_NULL ? bep : C_NULL
end


function ImGui_ImplSDL2_NewFrame()
    bd = ImGui_ImplSDL2_GetBackendData()
    @assert bd != C_NULL# && "Did you call ImGui_ImplSDL2_Init()?"
    io = CImGui.GetIO()
    println("bd: ", bd)
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

    # if bd.PendingMouseLeaveFrame && bd.PendingMouseLeaveFrame >= CImGui.GetFrameCount() && bd.MouseButtonsDown == 0
    #     bd.MouseWindowID = 0
    #     bd.PendingMouseLeaveFrame = 0
    #     #io.AddMousePosEvent(-FLT_MAX, -FLT_MAX)
    # end

    #ImGui_ImplSDL2_UpdateMouseData()
    #ImGui_ImplSDL2_UpdateMouseCursor()

    # Update game controllers (if enabled and available)
    #ImGui_ImplSDL2_UpdateGamepads()
end
