module WindowManagerModule
    using ..JulGame
    export WindowManager
    
    """
        WindowManager

    Handles the creation, management, and destruction of the game window.
    """
    mutable struct WindowManager
        window::Ptr{SDL2.SDL_Window}
        windowName::String
        windowSize::Math.Vector2
        screenSize::Math.Vector2
        isWindowFocused::Bool
        isFullscreen::Bool
        isResizable::Bool
        isBorderless::Bool
        isVsyncEnabled::Bool
        displayMode::SDL2.SDL_DisplayMode
        renderScale::Math.Vector2f
        targetFrameRate::Int32
        allowHighDPI::Bool
        position::Math.Vector2
        fpsManager::Ref{SDL2.LibSDL2.FPSmanager}

        function WindowManager()
            this = new()
            
            this.window = C_NULL
            this.windowName = ""
            this.windowSize = Math.Vector2(0, 0)
            this.screenSize = Math.Vector2(0, 0)
            this.isWindowFocused = false
            this.isFullscreen = false
            this.isResizable = false
            this.isBorderless = false
            this.isVsyncEnabled = false
            this.renderScale = Math.Vector2f(1.0, 1.0)
            this.targetFrameRate = 60
            this.allowHighDPI = false
            this.position = Math.Vector2(SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED)
            this.fpsManager = Ref(SDL2.LibSDL2.FPSmanager(UInt32(0), Cfloat(0.0), UInt32(0), UInt32(0), UInt32(0)))
            SDL2.SDL_initFramerate(this.fpsManager)
			SDL2.SDL_setFramerate(this.fpsManager, UInt32(this.targetFrameRate))
            
            return this
        end
    end

    """
        create_window(this::WindowManager, windowName::String, size::Math.Vector2, isFullscreen::Bool=false, isResizable::Bool=false)

    Creates and initializes the game window with the specified parameters.
    """
    function create_window(this::WindowManager, windowName::String, size::Math.Vector2, isFullscreen::Bool=false, isResizable::Bool=false)
        @debug "Creating window"
        this.windowName = windowName
        this.windowSize = size
        this.screenSize = size
        this.isFullscreen = isFullscreen
        this.isResizable = isResizable

        # Determine window flags based on settings
        flags = SDL2.SDL_WINDOW_SHOWN
        if isResizable
            flags |= SDL2.SDL_WINDOW_RESIZABLE
        end
        if isFullscreen
            flags |= SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP
        end
        if this.isBorderless
            flags |= SDL2.SDL_WINDOW_BORDERLESS
        end
        if this.allowHighDPI
            flags |= SDL2.SDL_WINDOW_ALLOW_HIGHDPI
        end

        # Create the window
        this.window = SDL2.SDL_CreateWindow(
            this.windowName, 
            this.position.x, 
            this.position.y, 
            this.screenSize.x, 
            this.screenSize.y, 
            flags
        )
        
        if this.window == C_NULL
            @error "Failed to create window with name $(this.windowName), size $(this.screenSize), flags $(flags), $(unsafe_string(SDL2.SDL_GetError()))"
            return false
        end

        # Get and store the current display mode
        display_index = SDL2.SDL_GetWindowDisplayIndex(this.window)
        current_mode = Ref{SDL2.SDL_DisplayMode}()
        if SDL2.SDL_GetCurrentDisplayMode(display_index, current_mode) == 0
            this.displayMode = current_mode[]
        else
            @warn "Failed to get current display mode: $(unsafe_string(SDL2.SDL_GetError()))"
        end
        
        return true
    end

    function create_window(windowName::String, size::Math.Vector2, isFullscreen::Bool=false, isResizable::Bool=false)
        return create_window(JulGame.MAIN.windowManager, windowName, size, isFullscreen, isResizable)
    end

    """
        resize_window(this::WindowManager, width::Int32, height::Int32)

    Resizes the window to the specified dimensions.
    """
    function resize_window(this::WindowManager, width::Int32, height::Int32)
        if this.window == C_NULL
            @error "Cannot resize window: Window has not been created"
            return
        end
        
        this.windowSize = Math.Vector2(width, height)
        SDL2.SDL_SetWindowSize(this.window, width, height)
    end

    function resize_window(width::Int32, height::Int32)
        resize_window(JulGame.MAIN.windowManager, width, height)
    end

    """
        toggle_fullscreen(this::WindowManager)

    Toggles between fullscreen and windowed mode.
    """
    function toggle_fullscreen(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot toggle fullscreen: Window has not been created"
            return
        end
        
        this.isFullscreen = !this.isFullscreen
        set_fullscreen(this, this.isFullscreen)
    end

    function toggle_fullscreen()
        toggle_fullscreen(JulGame.MAIN.windowManager)
    end

    """
        set_fullscreen(this::WindowManager, fullscreen::Bool)

    Sets the fullscreen state of the window.
    """
    function set_fullscreen(this::WindowManager, fullscreen::Bool)
        if this.window == C_NULL
            @error "Cannot set fullscreen: Window has not been created"
            return
        end
        
        flag = fullscreen ? SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP : 0
        SDL2.SDL_SetWindowFullscreen(this.window, flag)
        this.isFullscreen = fullscreen
    end

    function set_fullscreen(fullscreen::Bool)
        set_fullscreen(JulGame.MAIN.windowManager, fullscreen)
    end

    """
        set_borderless_fullscreen(this::WindowManager, enable::Bool)

    Enables or disables borderless fullscreen mode (windowed fullscreen).
    """
    function set_borderless_fullscreen(this::WindowManager, enable::Bool)
        if this.window == C_NULL
            @error "Cannot set borderless fullscreen: Window has not been created"
            return
        end
        
        if enable
            # Save current position and size for restoration later
            x = Ref{Cint}(0)
            y = Ref{Cint}(0)
            SDL2.SDL_GetWindowPosition(this.window, x, y)
            this.position = Math.Vector2(x[], y[])
            
            # Get the display dimensions
            display_index = SDL2.SDL_GetWindowDisplayIndex(this.window)
            mode = Ref{SDL2.SDL_DisplayMode}()
            if SDL2.SDL_GetCurrentDisplayMode(display_index, mode) == 0
                # Go borderless and resize to fill screen
                this.isBorderless = true
                SDL2.SDL_SetWindowBordered(this.window, SDL2.SDL_FALSE)
                SDL2.SDL_SetWindowSize(this.window, mode[].w, mode[].h)
                SDL2.SDL_SetWindowPosition(this.window, 0, 0)
            else
                @warn "Failed to get display mode: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        else
            # Restore window borders and original size
            this.isBorderless = false
            SDL2.SDL_SetWindowBordered(this.window, SDL2.SDL_TRUE)
            SDL2.SDL_SetWindowSize(this.window, this.windowSize.x, this.windowSize.y)
            SDL2.SDL_SetWindowPosition(this.window, this.position.x, this.position.y)
        end
    end

    function set_borderless_fullscreen(enable::Bool)
        set_borderless_fullscreen(JulGame.MAIN.windowManager, enable)
    end

    """
        toggle_borderless(this::WindowManager)

    Toggles the window border.
    """
    function toggle_borderless(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot toggle borderless: Window has not been created"
            return
        end
        
        this.isBorderless = !this.isBorderless
        SDL2.SDL_SetWindowBordered(this.window, this.isBorderless ? SDL2.SDL_FALSE : SDL2.SDL_TRUE)
    end

    function toggle_borderless()
        toggle_borderless(JulGame.MAIN.windowManager)
    end

    """
        set_vsync(this::WindowManager, enabled::Bool)

    Enables or disables vertical synchronization.
    """
    function set_vsync(this::WindowManager, enabled::Bool)
        if JulGame.Renderer == C_NULL
            @error "Cannot set vsync: Renderer has not been created"
            return
        end
        
        result = SDL2.SDL_GL_SetSwapInterval(enabled ? 1 : 0)
        if result == 0
            this.isVsyncEnabled = enabled
            @debug "VSync $(enabled ? "enabled" : "disabled")"
        else
            @warn "Failed to set VSync: $(unsafe_string(SDL2.SDL_GetError()))"
        end
    end

    function set_vsync(enabled::Bool)
        set_vsync(JulGame.MAIN.windowManager, enabled)
    end

    """
        toggle_vsync(this::WindowManager)

    Toggles vertical synchronization on/off.
    """
    function toggle_vsync(this::WindowManager)
        toggle_vsync(JulGame.MAIN.windowManager)
    end

    """
        set_render_scale(this::WindowManager, scaleX::Float32, scaleY::Float32)

    Sets the scaling factor used for rendering. This allows rendering at different resolutions than the window size.
    """
    function set_render_scale(this::WindowManager, scaleX::Float32, scaleY::Float32)
        if JulGame.Renderer == C_NULL
            @error "Cannot set render scale: Renderer has not been created"
            return
        end
        
        result = SDL2.SDL_RenderSetScale(JulGame.Renderer, scaleX, scaleY)
        if result == 0
            this.renderScale = Math.Vector2f(scaleX, scaleY)
            @debug "Render scale set to ($scaleX, $scaleY)"
        else
            @warn "Failed to set render scale: $(unsafe_string(SDL2.SDL_GetError()))"
        end
    end

    function set_render_scale(scaleX::Float32, scaleY::Float32)
        set_render_scale(JulGame.MAIN.windowManager, scaleX, scaleY)
    end

    """
        set_logical_size(this::WindowManager, width::Int32, height::Int32)

    Sets a device independent resolution for rendering.
    """
    function set_logical_size(this::WindowManager, width::Int32, height::Int32)
        if JulGame.Renderer == C_NULL
            @error "Cannot set logical size: Renderer has not been created"
            return
        end
        
        result = SDL2.SDL_RenderSetLogicalSize(JulGame.Renderer, width, height)
        if result == 0
            @debug "Logical size set to ($width, $height)"
        else
            @warn "Failed to set logical size: $(unsafe_string(SDL2.SDL_GetError()))"
        end
    end

    function set_logical_size(width::Int32, height::Int32)
        set_logical_size(JulGame.MAIN.windowManager, width, height)
    end

    """
        set_display_mode(this::WindowManager, width::Int32, height::Int32, refresh_rate::Int32)

    Attempts to set the display mode to the specified parameters.
    """
    function set_display_mode(this::WindowManager, width::Int32, height::Int32, refresh_rate::Int32 = 0)
        if this.window == C_NULL
            @error "Cannot set display mode: Window has not been created"
            return
        end
        
        # Create desired display mode
        desired_mode = SDL2.SDL_DisplayMode(0, width, height, refresh_rate, C_NULL)
        
        # Get closest supported mode
        display_index = SDL2.SDL_GetWindowDisplayIndex(this.window)
        closest_mode = Ref{SDL2.SDL_DisplayMode}()
        result = SDL2.SDL_GetClosestDisplayMode(display_index, Ref(desired_mode), closest_mode)
        
        if result != C_NULL
            # Set the display mode
            if SDL2.SDL_SetWindowDisplayMode(this.window, closest_mode) == 0
                this.displayMode = closest_mode[]
                @debug "Display mode set to $(closest_mode[].w)x$(closest_mode[].h) @ $(closest_mode[].refresh_rate)Hz"
            else
                @warn "Failed to set display mode: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        else
            @warn "Failed to find compatible display mode"
        end
    end

    function set_display_mode(width::Int32, height::Int32, refresh_rate::Int32 = 0)
        set_display_mode(JulGame.MAIN.windowManager, width, height, refresh_rate)
    end

    """
        center_window(this::WindowManager)

    Centers the window on the screen.
    """
    function center_window(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot center window: Window has not been created"
            return
        end
        
        SDL2.SDL_SetWindowPosition(this.window, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED)
        
        # Update stored position
        x = Ref{Cint}(0)
        y = Ref{Cint}(0)
        SDL2.SDL_GetWindowPosition(this.window, x, y)
        this.position = Math.Vector2(x[], y[])
    end

    function center_window()
        center_window(JulGame.MAIN.windowManager)
    end

    """
        set_window_position(this::WindowManager, x::Int32, y::Int32)

    Sets the position of the window.
    """
    function set_window_position(this::WindowManager, x::Int32, y::Int32)
        if this.window == C_NULL
            @error "Cannot set window position: Window has not been created"
            return
        end
        
        SDL2.SDL_SetWindowPosition(this.window, x, y)
        this.position = Math.Vector2(x, y)
    end

    function set_window_position(x::Int32, y::Int32)
        set_window_position(JulGame.MAIN.windowManager, x, y)
    end

    """
        set_window_title(this::WindowManager, title::String)

    Sets the window title.
    """
    function set_window_title(this::WindowManager, title::String)
        if this.window == C_NULL
            @error "Cannot set window title: Window has not been created"
            return
        end
        
        this.windowName = title
        SDL2.SDL_SetWindowTitle(this.window, title)
    end

    function set_window_title(title::String)
        set_window_title(JulGame.MAIN.windowManager, title)
    end

    """
        set_frame_rate(this::WindowManager, frameRate::Int32)

    Sets the target frame rate for the game.
    """
    function set_frame_rate(this::WindowManager, frameRate::Int32)
        if JulGame.MAIN !== nothing
            this.targetFrameRate = frameRate
            SDL2.SDL_setFramerate(this.fpsManager, UInt32(frameRate))
            @debug "Frame rate set to $frameRate FPS"
        else
            @warn "Cannot set frame rate: Main loop not initialized"
        end
    end

    function set_frame_rate(frameRate::Int32)
        set_frame_rate(JulGame.MAIN.windowManager, frameRate)
    end

    """
        set_window_icon(this::WindowManager, iconPath::String)

    Sets the window icon from an image file.
    """
    function set_window_icon(this::WindowManager, iconPath::String)
        if this.window == C_NULL
            @error "Cannot set window icon: Window has not been created"
            return
        end
        
        fullPath = joinpath(JulGame.BasePath, "assets", "images", iconPath)
        surface = SDL2.IMG_Load(fullPath)
        
        if surface == C_NULL
            @error "Failed to load icon image: $(unsafe_string(SDL2.SDL_GetError()))"
            return
        end
        
        SDL2.SDL_SetWindowIcon(this.window, surface)
        SDL2.SDL_FreeSurface(surface)
        
        @debug "Window icon set to $iconPath"
    end

    function set_window_icon(iconPath::String)
        set_window_icon(JulGame.MAIN.windowManager, iconPath)
    end

    """
        set_window_opacity(this::WindowManager, opacity::Float32)

    Sets the opacity of the window (if supported by the platform).
    """
    function set_window_opacity(this::WindowManager, opacity::Float32)
        if this.window == C_NULL
            @error "Cannot set window opacity: Window has not been created"
            return
        end
        
        # Clamp opacity between 0.0 and 1.0
        opacity = clamp(opacity, 0.0f0, 1.0f0)
        
        result = SDL2.SDL_SetWindowOpacity(this.window, opacity)
        if result != 0
            @warn "Failed to set window opacity: $(unsafe_string(SDL2.SDL_GetError()))"
        end
    end

    function set_window_opacity()
        set_window_opacity(JulGame.MAIN.windowManager, opacity)
    end

    """
        toggle_resizable(this::WindowManager)

    Toggles whether the window can be resized by the user.
    """
    function toggle_resizable(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot toggle resizable: Window has not been created"
            return
        end
        
        this.isResizable = !this.isResizable
        SDL2.SDL_SetWindowResizable(this.window, this.isResizable ? SDL2.SDL_TRUE : SDL2.SDL_FALSE)
    end

    function toggle_resizable()
        toggle_resizable(JulGame.MAIN.windowManager)
    end

    """
        set_resizable(this::WindowManager, resizable::Bool)

    Sets whether the window can be resized by the user.
    """
    function set_resizable(this::WindowManager, resizable::Bool)
        if this.window == C_NULL
            @error "Cannot set resizable: Window has not been created"
            return
        end
        
        this.isResizable = resizable
        SDL2.SDL_SetWindowResizable(this.window, resizable ? SDL2.SDL_TRUE : SDL2.SDL_FALSE)
    end

    function set_resizable(resizable::Bool)
        set_resizable(JulGame.MAIN.windowManager, resizable)
    end

    """
        get_window_size(this::WindowManager)::Math.Vector2

    Returns the current window size.
    """
    function get_window_size(this::WindowManager)::Math.Vector2
        if this.window == C_NULL
            return Math.Vector2(0, 0)
        end
        
        width = Ref{Cint}(0)
        height = Ref{Cint}(0)
        SDL2.SDL_GetWindowSize(this.window, width, height)
        
        return Math.Vector2(width[], height[])
    end

    function JulGame.get_window_size()
        get_window_size(JulGame.MAIN.windowManager)
    end

    """
        get_display_dimensions(this::WindowManager)::Math.Vector2

    Gets the dimensions of the display the window is on.
    """
    function get_display_dimensions(this::WindowManager)::Math.Vector2
        if this.window == C_NULL
            @error "Cannot get display dimensions: Window has not been created"
            return Math.Vector2(0, 0)
        end
        
        display_index = SDL2.SDL_GetWindowDisplayIndex(this.window)
        mode = Ref{SDL2.SDL_DisplayMode}()
        
        if SDL2.SDL_GetCurrentDisplayMode(display_index, mode) == 0
            return Math.Vector2(mode[].w, mode[].h)
        else
            @warn "Failed to get display dimensions: $(unsafe_string(SDL2.SDL_GetError()))"
            return Math.Vector2(0, 0)
        end
    end

    function get_display_dimensions()
        get_display_dimensions(JulGame.MAIN.windowManager)
    end

    """
        get_display_refresh_rate(this::WindowManager)::Int32

    Gets the refresh rate of the display the window is on.
    """
    function get_display_refresh_rate(this::WindowManager)::Int32
        if this.window == C_NULL
            @error "Cannot get display refresh rate: Window has not been created"
            return 0
        end
        
        display_index = SDL2.SDL_GetWindowDisplayIndex(this.window)
        mode = Ref{SDL2.SDL_DisplayMode}()
        
        if SDL2.SDL_GetCurrentDisplayMode(display_index, mode) == 0
            return mode[].refresh_rate
        else
            @warn "Failed to get display refresh rate: $(unsafe_string(SDL2.SDL_GetError()))"
            return 0
        end
    end

    function get_display_refresh_rate()
        get_display_refresh_rate(JulGame.MAIN.windowManager)
    end

    """
        minimize_window(this::WindowManager)

    Minimizes the window.
    """
    function minimize_window(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot minimize window: Window has not been created"
            return
        end
        
        SDL2.SDL_MinimizeWindow(this.window)
    end

    function minimize_window()
        minimize_window(JulGame.MAIN.windowManager)
    end

    """
        maximize_window(this::WindowManager)

    Maximizes the window.
    """
    function maximize_window(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot maximize window: Window has not been created"
            return
        end
        
        SDL2.SDL_MaximizeWindow(this.window)
    end

    function maximize_window()
        maximize_window(JulGame.MAIN.windowManager)
    end

    """
        restore_window(this::WindowManager)

    Restores the window to its original size and position.
    """
    function restore_window(this::WindowManager)
        if this.window == C_NULL
            @error "Cannot restore window: Window has not been created"
            return
        end
        
        SDL2.SDL_RestoreWindow(this.window)
    end

    function restore_window()
        restore_window(JulGame.MAIN.windowManager)
    end

    """
        handle_window_event(this::WindowManager, event::SDL2.SDL_WindowEvent)

    Handles window events like resizing, focus changes, etc.
    """
    function handle_window_event(this::WindowManager, windowEvent)
        if windowEvent == SDL2.SDL_WINDOWEVENT_FOCUS_GAINED
            this.isWindowFocused = true
            @debug "Window focus gained"
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_FOCUS_LOST
            this.isWindowFocused = false
            @debug "Window focus lost"
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_RESIZED
            width = windowEvent.data1
            height = windowEvent.data2
            this.windowSize = Math.Vector2(width, height)
            @debug "Window resized to $(width)x$(height)"
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_SHOWN
            @debug(string("Window $(event.window.windowID) shown"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_HIDDEN
            @debug(string("Window $(event.window.windowID) hidden"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_EXPOSED
            @debug(string("Window $(event.window.windowID) exposed"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_MOVED
            @debug(string("Window $(event.window.windowID) moved to $(event.window.data1),$(event.window.data2)"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_SIZE_CHANGED
            @debug(string("Window $(event.window.windowID) size changed to $(event.window.data1)x$(event.window.data2)"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_MINIMIZED
            @debug(string("Window $(event.window.windowID) minimized"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_MAXIMIZED
            @debug(string("Window $(event.window.windowID) maximized"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_RESTORED
            @debug(string("Window $(event.window.windowID) restored"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_ENTER
            @debug(string("Mouse entered window $(event.window.windowID)"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_LEAVE
            @debug(string("Mouse left window $(event.window.windowID)"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_CLOSE
            @debug(string("Window $(event.window.windowID) closed"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_TAKE_FOCUS
            @debug(string("Window $(event.window.windowID) is offered a focus"))
        elseif windowEvent == SDL2.SDL_WINDOWEVENT_HIT_TEST
            @debug(string("Window $(event.window.windowID) has a special hit test"))
        else
            @debug(string("Window $(event.window.windowID) got unknown event $(event.window.event)"))   
        end    
    end

    function handle_window_event(event)
        handle_window_event(JulGame.MAIN.windowManager, event)
    end

    """
        close_window(this::WindowManager)

    Closes and destroys the window.
    """
    function close_window(this::WindowManager)
        @debug "Closing window"
        if this.window != C_NULL
            SDL2.SDL_DestroyWindow(this.window)
            this.window = C_NULL
            if unsafe_string(SDL2.SDL_GetError()) != ""
                @error "Failed to destroy window, $(unsafe_string(SDL2.SDL_GetError()))"
            end
        end
    end

    function close_window()
        close_window(JulGame.MAIN.windowManager)
    end
end 