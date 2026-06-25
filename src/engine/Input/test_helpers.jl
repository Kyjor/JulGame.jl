 # Initialize an SDL_Event instance
 function init_sdl_event()::Ptr{SDL2.SDL_Event}
    # Create a vector of UInt8
    data = UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

     # Convert the vector to a tuple of size 56
    ntuple_data = Tuple(data)

    # Allocate memory for the SDL_Event struct itself
    ptr_event = Ptr{SDL2.SDL_Event}(Libc.malloc(sizeof(SDL2.SDL_Event)))  # Allocate memory for SDL_Event struct

    # Now, initialize the data field of the struct using unsafe_store!
    unsafe_store!(ptr_event, SDL2.SDL_Event(ntuple_data))

    # Return the pointer to the struct
    return ptr_event
end

function init_mouse_button_event()::Ptr{SDL2.SDL_MouseButtonEvent}
    # Allocate memory for SDL_MouseButtonEvent struct
    ptr_event = Ptr{SDL2.SDL_MouseButtonEvent}(Libc.malloc(sizeof(SDL2.SDL_MouseButtonEvent)))

    # Initialize the fields directly
    unsafe_store!(ptr_event, SDL2.SDL_MouseButtonEvent(
        0x0,             # type (just an example, you'll set this later)
        0x0,             # timestamp
        0x0,             # windowID
        0x0,             # which (mouse)
        0x0,             # button (mouse button)
        0x0,             # state (pressed/released)
        0x0,             # clicks
        0x0,             # padding
        0x0,             # x (position)
        0x0              # y (position)
    ))

    # Return the pointer to the struct
    return ptr_event
end

function simulate_mouse_click(this::Input, window::Ptr{SDL2.SDL_Window}, x::Number, y::Number)
    # Get current window size
    window_width = Ref{Cint}(0)
    window_height = Ref{Cint}(0)
    SDL2.SDL_GetWindowSize(window, window_width, window_height)

    # Get base resolution from WindowManager
    logical_size = JulGame.WindowManagerModule.get_logical_size()

    safe_window_width = max(window_width[], 1)
    safe_window_height = max(window_height[], 1)
    safe_logical_width = max(logical_size.x, 1)
    safe_logical_height = max(logical_size.y, 1)
    scale_x = safe_window_width / safe_logical_width
    scale_y = safe_window_height / safe_logical_height
    scale = min(scale_x, scale_y)
    content_width = safe_logical_width * scale
    content_height = safe_logical_height * scale
    bar_x = (safe_window_width - content_width) / 2
    bar_y = (safe_window_height - content_height) / 2

    # Convert logical coordinates to window coordinates (inverse of poll_input mapping)
    window_x = round(Int, (x * scale) + bar_x)
    window_y = round(Int, (y * scale) + bar_y)
    x = Math.TypeConversions.safe_int32_convert(window_x)
    y = Math.TypeConversions.safe_int32_convert(window_y)
    # Move the mouse to the specified position
    @debug "Moving mouse to $(x), $(y)"
    SDL2.SDL_WarpMouseInWindow(window, x, y)

    # Create a mouse button down event
    mouse_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
    mouse_event.type = SDL2.SDL_MOUSEBUTTONDOWN

    mouse_event.button = SDL2.SDL_MouseButtonEvent(
        SDL2.SDL_MOUSEBUTTONDOWN,  # Type of event
        0,                        # Timestamp (0 for automatic)
        0,                        # Window ID (0 for default window)
        0,                        # Which mouse (0 for the primary mouse)
        SDL2.SDL_BUTTON_LEFT,      # Button being pressed
        SDL2.SDL_PRESSED,          # Button state (pressed)
        1,                         # Clicks (1 for single click)
        0,                         # Padding (unused, set to 0)
        x,                         # X position
        y                          # Y position
    )
    SDL2.SDL_PushEvent(mouse_event)
    
    # Immediately push button up event as well so both are processed together
    # This is especially important when window isn't focused
    mouse_up_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
    mouse_up_event.type = SDL2.SDL_MOUSEBUTTONUP
    mouse_up_event.button = SDL2.SDL_MouseButtonEvent(
        SDL2.SDL_MOUSEBUTTONUP,  # Type of event
        0,                        # Timestamp (0 for automatic)
        0,                        # Window ID (0 for default window)
        0,                        # Which mouse (0 for the primary mouse)
        SDL2.SDL_BUTTON_LEFT,      # Button being pressed
        SDL2.SDL_RELEASED,         # Button state (released)
        1,                         # Clicks (1 for single click)
        0,                         # Padding (unused, set to 0)
        x,                         # X position (same as button down)
        y                          # Y position (same as button down)
    )
    SDL2.SDL_PushEvent(mouse_up_event)
    
    this.isTestButtonClicked = false  # No need to lift later since we pushed it immediately
    this.simulatedClickPosition = nothing
end

function simulate_mouse_click(x::Number, y::Number)
    simulate_mouse_click(MAIN.input, MAIN.windowManager.window, x, y)
end

function lift_mouse_after_simulated_click(this)
    # Use the stored click position, or current mouse position as fallback
    if this.simulatedClickPosition !== nothing
        click_x = Int32(this.simulatedClickPosition.x)
        click_y = Int32(this.simulatedClickPosition.y)
    else
        # Fallback to current mouse position
        x_ref, y_ref = Ref{Cint}(0), Ref{Cint}(0)
        SDL2.SDL_GetMouseState(x_ref, y_ref)
        click_x = Int32(x_ref[])
        click_y = Int32(y_ref[])
    end
    
    mouse_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
    mouse_event.type = SDL2.SDL_MOUSEBUTTONUP
    mouse_event.button = SDL2.SDL_MouseButtonEvent(
        SDL2.SDL_MOUSEBUTTONUP,  # Type of event
        0,                        # Timestamp (0 for automatic)
        0,                        # Window ID (0 for default window)
        0,                        # Which mouse (0 for the primary mouse)
        SDL2.SDL_BUTTON_LEFT,      # Button being pressed
        SDL2.SDL_RELEASED,          # Button state (released)
        1,                         # Clicks (1 for single click)
        0,                         # Padding (unused, set to 0)
        click_x,                   # X position (same as button down)
        click_y                    # Y position (same as button down)
    )
    SDL2.SDL_PushEvent(mouse_event)
    this.isTestButtonClicked = false
    this.simulatedClickPosition = nothing
end

function lift_mouse_after_simulated_click()
    lift_mouse_after_simulated_click(MAIN.input)
end

function simulate_key_press(this::Input, key::String)
    # Create a keyboard event
    key_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
    key_event.type = SDL2.SDL_KEYDOWN
    key_event.key = SDL2.SDL_KeyboardEvent(
        SDL2.SDL_KEYDOWN,  # Type of event
        0,                 # Timestamp (0 for automatic)
        0,                 # Window ID (0 for default window)
        0,                 # State (pressed)
        0,                 # Repeat (0 for no repeat)
        0,                 # Padding
        0,                 # Padding
        SDL2.SDL_Keysym(   # Keysym structure
            SDL2.SDL_SCANCODE_SPACE, # Scancode
            0,  # Keycode
            0,                                   # Modifiers (none)
            0                                    # Window ID (0 for default window)
        )
    )
    # key_event.key.keysym.sym = SDL2.SDL_Keycode(uppercase(key))
    # key_event.key.keysym.scancode = SDL2.SDL_Scancode(uppercase(key))
    # key_event.key.keysym.mod = 0
    # key_event.key.keysym.windowID = 0

    # Push the event to the event queue
    SDL2.SDL_PushEvent(key_event)
end

function simulate_key_press(key::String)
    simulate_key_press(MAIN.input, key)
end
