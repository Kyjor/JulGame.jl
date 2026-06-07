export {}
import { clamp, joinpath, unsafe_string } from "../../../../src/engine/core/juliaHelpers";


    // using ..JulGame
    
    
    /*
        WindowManager

    Handles the creation, management, and destruction of the game window.
    */
    class WindowManager {
        window: any
        windowName: string
        windowSize: Vector2
        screenSize: Vector2
        isWindowFocused: boolean
        isFullscreen: boolean
        isResizable: boolean
        isBorderless: boolean
        isVsyncEnabled: boolean
        displayMode: any
        renderScale: Vector2f
        targetFrameRate: number
        allowHighDPI: boolean
        position: Vector2
        fpsManager: Ref{SDL2.LibSDL2.FPSmanager}
        baseResolution: Vector2

        constructor() {
            
            
            this.window = null
            this.windowName = ""
            this.windowSize = {x: 0, y: 0}
            this.screenSize = {x: 0, y: 0}
            this.isWindowFocused = false
            this.isFullscreen = false
            this.isResizable = false
            this.isBorderless = false
            this.isVsyncEnabled = false
            this.renderScale = {x: 1.0, y: 1.0}
            this.targetFrameRate = 60
            this.allowHighDPI = false
            this.position = {x: (globalThis as any).JulGameSdl.glue_SDL_WINDOWPOS_CENTERED, y: (globalThis as any).JulGameSdl.glue_SDL_WINDOWPOS_CENTERED}
            this.fpsManager = SDL2.LibSDL2.FPSmanager(0, Cfloat(0.0), 0, 0, 0);
            (globalThis as any).JulGameSdl.glue_SDL_initFramerate(this.fpsManager);
			(globalThis as any).JulGameSdl.glue_SDL_setFramerate(this.fpsManager, ((this.targetFrameRate) >>> 0))
            this.baseResolution = {x: 1280, y: 720}

        }
    }

    /*
        create_window(this, windowName: string, size, isFullscreen: boolean=false, isResizable: boolean=false)

    Creates and initializes the game window with the specified parameters.
    */
    function create_window(self: WindowManager, windowName: string, size: Vector2, isFullscreen: boolean=false, isResizable: boolean=false) {
        console.debug("Creating window")
        self.windowName = windowName
        self.windowSize = size
        self.screenSize = size
        self.isFullscreen = isFullscreen
        self.isResizable = isResizable

        // Determine window flags based on settings
        let flags = (globalThis as any).JulGameSdl.glue_SDL_WINDOW_SHOWN
        if (isResizable) {
            flags |= (globalThis as any).JulGameSdl.glue_SDL_WINDOW_RESIZABLE
        }
        if (isFullscreen) {
            flags |= (globalThis as any).JulGameSdl.glue_SDL_WINDOW_FULLSCREEN_DESKTOP
        }
        if (self.isBorderless) {
            flags |= (globalThis as any).JulGameSdl.glue_SDL_WINDOW_BORDERLESS
        }
        if (self.allowHighDPI) {
            flags |= (globalThis as any).JulGameSdl.glue_SDL_WINDOW_ALLOW_HIGHDPI
        }

        // Create the window
        self.window = (globalThis as any).JulGameSdl.glue_SDL_CreateWindow(
            self.windowName, 
            self.position.x, 
            self.position.y, 
            self.screenSize.x, 
            self.screenSize.y, 
            flags
        )
        
        if (self.window == null) {
            console.error(`Failed to create window with name ${self.windowName}, size ${self.screenSize}, flags ${flags}, ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return false
        }

        // Get and store the current display mode
        let display_index = (globalThis as any).JulGameSdl.glue_SDL_GetWindowDisplayIndex(self.window)
        let current_mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
        if ((globalThis as any).JulGameSdl.glue_SDL_GetCurrentDisplayMode(display_index, current_mode) == 0) {
            self.displayMode = current_mode
        } else {
            console.warn(`Failed to get current display mode: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        }
        
        return true
    }

    function create_window(windowName: string, size: Vector2, isFullscreen: boolean=false, isResizable: boolean=false) {
        return create_window((globalThis as any).JulGame.MAIN.windowManager, windowName, size, isFullscreen, isResizable)
    }

    /*
        resize_window(this, width: number, height: number)

    Resizes the window to the specified dimensions.
    */
    function resize_window(self: WindowManager, width: number, height: number) {
        if (self.window == null) {
            console.error("Cannot resize window: Window has not been created")
            return
        }
        
        self.windowSize = {x: width, y: height};
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowSize(self.window, width, height)
    }

    function resize_window(width: number, height: number) {
        resize_window((globalThis as any).JulGame.MAIN.windowManager, width, height)
    }

    /*
        toggle_fullscreen(this)

    Toggles between fullscreen and windowed mode.
    */
    function toggle_fullscreen(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot toggle fullscreen: Window has not been created")
            return
        }
        
        self.isFullscreen = !self.isFullscreen
        set_fullscreen(self, self.isFullscreen)
    }

    function toggle_fullscreen() {
        toggle_fullscreen((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_fullscreen(this, fullscreen: boolean)

    Sets the fullscreen state of the window.
    */
    function set_fullscreen(self: WindowManager, fullscreen: boolean) {
        if (self.window == null) {
            console.error("Cannot set fullscreen: Window has not been created")
            return
        }
        
        let flag = fullscreen ? (globalThis as any).JulGameSdl.glue_SDL_WINDOW_FULLSCREEN_DESKTOP : 0;
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowFullscreen(self.window, flag)
        self.isFullscreen = fullscreen
    }

    function set_fullscreen(fullscreen: boolean) {
        set_fullscreen((globalThis as any).JulGame.MAIN.windowManager, fullscreen)
    }

    /*
        set_borderless_fullscreen(this, enable: boolean)

    Enables or disables borderless fullscreen mode (windowed fullscreen).
    */
    function set_borderless_fullscreen(self: WindowManager, enable: boolean) {
        if (self.window == null) {
            console.error("Cannot set borderless fullscreen: Window has not been created")
            return
        }
        
        if (enable) {
            // Save current position and size for restoration later
            let x = [0]
            let y = [0];
            (globalThis as any).JulGameSdl.glue_SDL_GetWindowPosition(self.window, ...x, ...y)
            self.position = {x: x[0], y: y[0]}
            
            // Get the display dimensions
            let display_index = (globalThis as any).JulGameSdl.glue_SDL_GetWindowDisplayIndex(self.window)
            let mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
            if ((globalThis as any).JulGameSdl.glue_SDL_GetCurrentDisplayMode(display_index, mode) == 0) {
                // Go borderless and resize to fill screen
                self.isBorderless = true;
                (globalThis as any).JulGameSdl.glue_SDL_SetWindowBordered(self.window, (globalThis as any).JulGameSdl.glue_SDL_FALSE);
                (globalThis as any).JulGameSdl.glue_SDL_SetWindowSize(self.window, mode.w, mode.h);
                (globalThis as any).JulGameSdl.glue_SDL_SetWindowPosition(self.window, 0, 0)
            } else {
                console.warn(`Failed to get display mode: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            }
        } else {
            // Restore window borders and original size
            self.isBorderless = false;
            (globalThis as any).JulGameSdl.glue_SDL_SetWindowBordered(self.window, (globalThis as any).JulGameSdl.glue_SDL_TRUE);
            (globalThis as any).JulGameSdl.glue_SDL_SetWindowSize(self.window, self.windowSize.x, self.windowSize.y);
            (globalThis as any).JulGameSdl.glue_SDL_SetWindowPosition(self.window, self.position.x, self.position.y)
        }
    }

    function set_borderless_fullscreen(enable: boolean) {
        set_borderless_fullscreen((globalThis as any).JulGame.MAIN.windowManager, enable)
    }

    /*
        toggle_borderless(this)

    Toggles the window border.
    */
    function toggle_borderless(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot toggle borderless: Window has not been created")
            return
        }
        
        self.isBorderless = !self.isBorderless;
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowBordered(self.window, self.isBorderless ? (globalThis as any).JulGameSdl.glue_SDL_FALSE : (globalThis as any).JulGameSdl.glue_SDL_TRUE)
    }

    function toggle_borderless() {
        toggle_borderless((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_vsync(this, enabled: boolean)

    Enables or disables vertical synchronization.
    */
    function set_vsync(self: WindowManager, enabled: boolean) {
        if ((globalThis as any).JulGame.Renderer == null) {
            console.error("Cannot set vsync: Renderer has not been created")
            return
        }
        
        let result = (globalThis as any).JulGameSdl.glue_SDL_GL_SetSwapInterval(enabled ? 1 : 0)
        if (result == 0) {
            self.isVsyncEnabled = enabled
            console.debug(`VSync $(enabled ? `)enabled" : "disabled")"
        } else {
            console.warn(`Failed to set VSync: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        }
    }

    function set_vsync(enabled: boolean) {
        set_vsync((globalThis as any).JulGame.MAIN.windowManager, enabled)
    }

    /*
        toggle_vsync(this)

    Toggles vertical synchronization on/off.
    */
    function toggle_vsync(self: WindowManager) {
        toggle_vsync((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_render_scale(this, scaleX: number, scaleY: number)

    Sets the scaling factor used for rendering. This allows rendering at different resolutions than the window size.
    */
    function set_render_scale(self: WindowManager, scaleX: number, scaleY: number) {
        if ((globalThis as any).JulGame.Renderer == null) {
            console.error("Cannot set render scale: Renderer has not been created")
            return
        }
        
        let result = (globalThis as any).JulGameSdl.glue_SDL_RenderSetScale((globalThis as any).JulGame.Renderer, scaleX, scaleY)
        if (result == 0) {
            self.renderScale = {x: scaleX, y: scaleY}
            console.debug(`Render scale set to (${scaleX}, ${scaleY})`)
        } else {
            console.warn(`Failed to set render scale: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        }
    }

    function set_render_scale(scaleX: number, scaleY: number) {
        set_render_scale((globalThis as any).JulGame.MAIN.windowManager, scaleX, scaleY)
    }

    /*
        set_logical_size(this, width: number, height: number)

    Sets a device independent resolution for rendering.
    */
    function set_logical_size(self: WindowManager, width: number, height: number) {
        if ((globalThis as any).JulGame.Renderer == null) {
            console.error("Cannot set logical size: Renderer has not been created")
            return
        }
        
        let result = (globalThis as any).JulGameSdl.glue_SDL_RenderSetLogicalSize((globalThis as any).JulGame.Renderer, width, height)
        if (result == 0) {
            console.debug(`Logical size set to (${width}, ${height})`)
        } else {
            console.warn(`Failed to set logical size: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        }
    }

    function set_logical_size(width: number, height: number) {
        set_logical_size((globalThis as any).JulGame.MAIN.windowManager, width, height)
    }

    function get_logical_size(self: WindowManager)
        if (this.window == null) {
            console.error("Cannot get logical size: Window has not been created")
            return {x: 0, y: 0}
        }

        let width = [0]
        let height = [0];
        (globalThis as any).JulGameSdl.glue_SDL_RenderGetLogicalSize((globalThis as any).JulGame.Renderer, width, height)

        return {x: width[0], y: height[0]}
    }


    /*
        get_logical_size()

    Gets the logical size of the window.
    */
    function get_logical_size() {
        get_logical_size((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_display_mode(this, width: number, height: number, refresh_rate: number)

    Attempts to set the display mode to the specified parameters.
    */
    function set_display_mode(self: WindowManager, width: number, height: number, refresh_rate: number = 0) {
        if (self.window == null) {
            console.error("Cannot set display mode: Window has not been created")
            return
        }
        
        // Create desired display mode
        let desired_mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode(0, width, height, refresh_rate, null)
        
        // Get closest supported mode
        let display_index = (globalThis as any).JulGameSdl.glue_SDL_GetWindowDisplayIndex(self.window)
        let closest_mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
        let result = (globalThis as any).JulGameSdl.glue_SDL_GetClosestDisplayMode(display_index, desired_mode, closest_mode)
        
        if (result != null) {
            // Set the display mode
            if ((globalThis as any).JulGameSdl.glue_SDL_SetWindowDisplayMode(self.window, closest_mode) == 0) {
                self.displayMode = closest_mode
                console.debug(`Display mode set to ${closest_mode.w}x${closest_mode.h} @ ${closest_mode.refresh_rate}Hz`)
            } else {
                console.warn(`Failed to set display mode: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            }
        } else {
            console.warn("Failed to find compatible display mode")
        }
    }

    function set_display_mode(width: number, height: number, refresh_rate: number = 0) {
        set_display_mode((globalThis as any).JulGame.MAIN.windowManager, width, height, refresh_rate)
    }

    /*
        center_window(this)

    Centers the window on the screen.
    */
    function center_window(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot center window: Window has not been created")
            return
        };
        
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowPosition(self.window, (globalThis as any).JulGameSdl.glue_SDL_WINDOWPOS_CENTERED, (globalThis as any).JulGameSdl.glue_SDL_WINDOWPOS_CENTERED)
        
        // Update stored position
        let x = [0]
        let y = [0];
        (globalThis as any).JulGameSdl.glue_SDL_GetWindowPosition(self.window, ...x, ...y)
        self.position = {x: x[0], y: y[0]}
    }

    function center_window() {
        center_window((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_window_position(this, x: number, y: number)

    Sets the position of the window.
    */
    function set_window_position(self: WindowManager, x: number, y: number) {
        if (self.window == null) {
            console.error("Cannot set window position: Window has not been created")
            return
        };
        
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowPosition(self.window, x, y)
        self.position = {x: x, y: y}
    }

    function set_window_position(x: number, y: number) {
        set_window_position((globalThis as any).JulGame.MAIN.windowManager, x, y)
    }

    /*
        set_window_title(this, title: string)

    Sets the window title.
    */
    function set_window_title(self: WindowManager, title: string) {
        if (self.window == null) {
            console.error("Cannot set window title: Window has not been created")
            return
        }
        
        self.windowName = title;
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowTitle(self.window, title)
    }

    function set_window_title(title: string) {
        set_window_title((globalThis as any).JulGame.MAIN.windowManager, title)
    }

    /*
        set_frame_rate(this, frameRate: number)

    Sets the target frame rate for the game.
    */
    function set_frame_rate(self: WindowManager, frameRate: number) {
        if ((globalThis as any).JulGame.MAIN !== null) {
            self.targetFrameRate = frameRate;
            (globalThis as any).JulGameSdl.glue_SDL_setFramerate(self.fpsManager, ((frameRate) >>> 0))
            console.debug(`Frame rate set to ${frameRate} FPS`)
        } else {
            console.warn("Cannot set frame rate: Main loop not initialized")
        }
    }

    function set_frame_rate(frameRate: number) {
        set_frame_rate((globalThis as any).JulGame.MAIN.windowManager, frameRate)
    }

    /*
        set_window_icon(this, iconPath: string)

    Sets the window icon from an image file.
    */
    function set_window_icon(self: WindowManager, iconPath: string) {
        if (self.window == null) {
            console.error("Cannot set window icon: Window has not been created")
            return
        }
        
        let fullPath = joinpath((globalThis as any).JulGame.BasePath, "assets", "images", iconPath)
        let surface = (globalThis as any).JulGameSdl.glue_IMG_Load(fullPath)
        
        if (surface == null) {
            console.error(`Failed to load icon image: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return
        };
        
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowIcon(self.window, surface);
        (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(surface)
        
        console.debug(`Window icon set to ${iconPath}`)
    }

    function set_window_icon(iconPath: string) {
        set_window_icon((globalThis as any).JulGame.MAIN.windowManager, iconPath)
    }

    /*
        set_window_opacity(this, opacity: number)

    Sets the opacity of the window (if supported by the platform).
    */
    function set_window_opacity(self: WindowManager, opacity: number) {
        if (self.window == null) {
            console.error("Cannot set window opacity: Window has not been created")
            return
        }
        
        // Clamp opacity between 0.0 and 1.0
        opacity = clamp(opacity, 0.0f0, 1.0f0)
        
        let result = (globalThis as any).JulGameSdl.glue_SDL_SetWindowOpacity(self.window, opacity)
        if (result != 0) {
            console.warn(`Failed to set window opacity: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        }
    }

    function set_window_opacity() {
        set_window_opacity((globalThis as any).JulGame.MAIN.windowManager, opacity)
    }

    /*
        toggle_resizable(this)

    Toggles whether the window can be resized by the user.
    */
    function toggle_resizable(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot toggle resizable: Window has not been created")
            return
        }
        
        self.isResizable = !self.isResizable;
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowResizable(self.window, self.isResizable ? (globalThis as any).JulGameSdl.glue_SDL_TRUE : (globalThis as any).JulGameSdl.glue_SDL_FALSE)
    }

    function toggle_resizable() {
        toggle_resizable((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_resizable(this, resizable: boolean)

    Sets whether the window can be resized by the user.
    */
    function set_resizable(self: WindowManager, resizable: boolean) {
        if (self.window == null) {
            console.error("Cannot set resizable: Window has not been created")
            return
        }
        
        self.isResizable = resizable;
        (globalThis as any).JulGameSdl.glue_SDL_SetWindowResizable(self.window, resizable ? (globalThis as any).JulGameSdl.glue_SDL_TRUE : (globalThis as any).JulGameSdl.glue_SDL_FALSE)
    }

    function set_resizable(resizable: boolean) {
        set_resizable((globalThis as any).JulGame.MAIN.windowManager, resizable)
    }

    /*
        get_window_size(this)

    Returns the current window size.
    */
    function get_window_size(self: WindowManager)
        if (this.window == null) {
            return {x: 0, y: 0}
        }
        
        let width = [0]
        let height = [0];
        (globalThis as any).JulGameSdl.glue_SDL_GetWindowSize(this.window, ...width, ...height)
        
        return {x: width[0], y: height[0]}
    }

    function JulGame_get_window_size() {
        get_window_size((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        get_display_dimensions(this)

    Gets the dimensions of the display the window is on.
    */
    function get_display_dimensions(self: WindowManager)
        if (this.window == null) {
            console.error("Cannot get display dimensions: Window has not been created")
            return {x: 0, y: 0}
        }
        
        let display_index = (globalThis as any).JulGameSdl.glue_SDL_GetWindowDisplayIndex(this.window)
        let mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
        
        if ((globalThis as any).JulGameSdl.glue_SDL_GetCurrentDisplayMode(display_index, mode) == 0) {
            return {x: mode.w, y: mode.h}
        } else {
            console.warn(`Failed to get display dimensions: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return {x: 0, y: 0}
        }
    }

    function get_display_dimensions() {
        get_display_dimensions((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        get_display_name(display_index: number): string

    Returns the human-readable display name for the given display index.
    */
    function get_display_name(display_index: number): string
        let name_ptr = (globalThis as any).JulGameSdl.glue_SDL_GetDisplayName(display_index)
        return name_ptr == null ? "" : unsafe_string(name_ptr)
    }

    /*
        get_available_displays(): Tuple{Int, String, (globalThis as any).JulGameSdl.glue_SDL_DisplayMode}

    Returns a list of available displays with their indices, names, and current display modes.
    */
    function get_available_displays(): Tuple{Int, String, (globalThis as any).JulGameSdl.glue_SDL_DisplayMode}
        let nd = (globalThis as any).JulGameSdl.glue_SDL_GetNumVideoDisplays()
        if (nd < 1) {
            console.warn(`No video displays reported: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return Tuple{Int, String, (globalThis as any).JulGameSdl.glue_SDL_DisplayMode}[]
        }

        let displays = Tuple{Int, String, (globalThis as any).JulGameSdl.glue_SDL_DisplayMode}[]
        for (const display_index of 0:(nd - 1)) {
            let mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
            if ((globalThis as any).JulGameSdl.glue_SDL_GetCurrentDisplayMode(display_index, mode) == 0) {
                displays.push((display_index, get_display_name(display_index), mode))
            } else {
                console.warn(`Failed to get current display mode for display ${display_index}: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            }
        }

        return displays
    }

    /*
        get_display_modes(display_index: number): any[]

    Returns all available display modes for the given display index.
    */
    function get_display_modes(display_index: number): any[]
        let ndm = (globalThis as any).JulGameSdl.glue_SDL_GetNumDisplayModes(display_index)
        if (ndm < 1) {
            console.warn(`No display modes reported for display ${display_index}: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return (globalThis as any).JulGameSdl.glue_SDL_DisplayMode
        }

        let modes = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode
        for (const i of 0:(ndm - 1)) {
            let mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
            if ((globalThis as any).JulGameSdl.glue_SDL_GetDisplayMode(display_index, i, mode) == 0) {
                modes.push(mode)
            } else {
                console.warn(`Failed to get display mode ${i} for display ${display_index}: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            }
        }

        return modes
    }

    /*
        get_display_refresh_rate(this): number

    Gets the refresh rate of the display the window is on.
    */
    function get_display_refresh_rate(self: WindowManager): number
        if (this.window == null) {
            console.error("Cannot get display refresh rate: Window has not been created")
            return 0
        }
        
        let display_index = (globalThis as any).JulGameSdl.glue_SDL_GetWindowDisplayIndex(this.window)
        let mode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode()
        
        if ((globalThis as any).JulGameSdl.glue_SDL_GetCurrentDisplayMode(display_index, mode) == 0) {
            return mode.refresh_rate
        } else {
            console.warn(`Failed to get display refresh rate: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return 0
        }
    }

    function get_display_refresh_rate() {
        get_display_refresh_rate((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        minimize_window(this)

    Minimizes the window.
    */
    function minimize_window(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot minimize window: Window has not been created")
            return
        };
        
        (globalThis as any).JulGameSdl.glue_SDL_MinimizeWindow(self.window)
    }

    function minimize_window() {
        minimize_window((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        maximize_window(this)

    Maximizes the window.
    */
    function maximize_window(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot maximize window: Window has not been created")
            return
        };
        
        (globalThis as any).JulGameSdl.glue_SDL_MaximizeWindow(self.window)
    }

    function maximize_window() {
        maximize_window((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        restore_window(this)

    Restores the window to its original size and position.
    */
    function restore_window(self: WindowManager) {
        if (self.window == null) {
            console.error("Cannot restore window: Window has not been created")
            return
        };
        
        (globalThis as any).JulGameSdl.glue_SDL_RestoreWindow(self.window)
    }

    function restore_window() {
        restore_window((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        handle_window_event(this, event)

    Handles window events like resizing, focus changes, etc.
    */
    function handle_window_event(self: WindowManager, event: any) {
        let windowEvent = event.event
        if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_FOCUS_GAINED) {
            self.isWindowFocused = true
            console.debug("Window focus gained")
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_FOCUS_LOST) {
            self.isWindowFocused = false
            console.debug("Window focus lost")
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_RESIZED) {
            let width = event.data1
            let height = event.data2
            self.windowSize = {x: width, y: height}
            console.debug(`Window resized to ${width}x${height}`)
            
            // Update all TextBoxes when window is resized
            if ((globalThis as any).JulGame.MAIN !== null && (globalThis as any).JulGame.MAIN.scene !== null) {
                for (const element of (globalThis as any).JulGame.MAIN.scene.uiElements) {
                    if ("$(typeof(element))" == "(globalThis as any).JulGame.UI.TextBoxModule.TextBox") {
                        (globalThis as any).JulGame.UI.handle_window_resize(element)
                    }
                }
            }
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_SHOWN) {
            console.debug(String("Window $(event.windowID) shown"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_HIDDEN) {
            console.debug(String("Window $(event.windowID) hidden"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_EXPOSED) {
            console.debug(String("Window $(event.windowID) exposed"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_MOVED) {
            console.debug(String("Window $(event.windowID) moved to $(event.data1),$(event.data2)"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_SIZE_CHANGED) {
            width = event.data1
            height = event.data2
            console.debug(String("Window $(event.windowID) size changed to $(event.data1)x$(event.data2)"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_MINIMIZED) {
            console.debug(String("Window $(event.windowID) minimized"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_MAXIMIZED) {
            console.debug(String("Window $(event.windowID) maximized"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_RESTORED) {
            console.debug(String("Window $(event.windowID) restored"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_ENTER) {
            console.debug(String("Mouse entered window $(event.windowID)"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_LEAVE) {
            console.debug(String("Mouse left window $(event.windowID)"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_CLOSE) {
            console.debug(String("Window $(event.windowID) closed"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_TAKE_FOCUS) {
            console.debug(String("Window $(event.windowID) is offered a focus"))
        } else if (windowEvent == (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT_HIT_TEST) {
            console.debug(String("Window $(event.windowID) has a special hit test"))
        } else {
            console.debug(String("Window $(event.windowID) got unknown event $(event.event)"))   
        }    
    }

    function handle_window_event(event: any) {
        handle_window_event((globalThis as any).JulGame.MAIN.windowManager, event)
    }

    /*
        close_window(this)

    Closes and destroys the window.
    */
    function close_window(self: WindowManager) {
        console.debug("Closing window")
        if (self.window != null) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyWindow(self.window)
            self.window = null
            if (unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()) != "") {
                console.error(`Failed to destroy window, ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            }
        }
    }

    function close_window() {
        close_window((globalThis as any).JulGame.MAIN.windowManager)
    }

    /*
        set_base_resolution(this, width: number, height: number)

    Sets the base resolution for UI scaling. This is the resolution that UI elements are designed for.
    The mouse coordinates and UI elements will be scaled relative to this resolution.

    // Arguments
    - `width: number`: The base width resolution
    - `height: number`: The base height resolution
    */
    function set_base_resolution(self: WindowManager, width: number, height: number) {
        if (width <= 0 || height <= 0) {
            console.error("Base resolution must be positive")
            return
        }
        self.baseResolution = {x: width, y: height}
        // (globalThis as any).JulGameSdl.glue_SDL_RenderSetLogicalSize((globalThis as any).JulGame.Renderer, self.baseResolution.x, self.baseResolution.y) // Commented out - let window events handle logical size
        console.debug(`Base resolution set to ${width}x${height}`)
    }

    function set_base_resolution(width: number, height: number) {
        set_base_resolution((globalThis as any).JulGame.MAIN.windowManager, width, height)
    }

    /*
        get_base_resolution(this)

    Gets the current base resolution used for UI scaling.

    // Returns
    - `Vector2`: The current base resolution
    */
    function get_base_resolution(self: WindowManager)
        return this.baseResolution
    }

    function get_base_resolution()
        return get_base_resolution((globalThis as any).JulGame.MAIN.windowManager)
    }
export { JulGame_get_window_size, WindowManager, center_window, close_window, create_window, get_available_displays, get_base_resolution, get_display_dimensions, get_display_modes, get_display_name, get_display_refresh_rate, get_logical_size, get_window_size, handle_window_event, maximize_window, minimize_window, resize_window, restore_window, set_base_resolution, set_borderless_fullscreen, set_display_mode, set_frame_rate, set_fullscreen, set_logical_size, set_render_scale, set_resizable, set_vsync, set_window_icon, set_window_opacity, set_window_position, set_window_title, toggle_borderless, toggle_fullscreen, toggle_resizable, toggle_vsync }
