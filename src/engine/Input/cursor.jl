 """
        set_cursor_with_image(this, imagePath, x, y, scale_factor)

        Loads an image as an SDL cursor, applies a scaling factor, and updates the hotspot position.

        # Arguments
        - `this::Input`: The input object storing the cursor reference.
        - `imagePath::String`: Path to the image file.
        - `x::Int, y::Int`: Original hotspot position in the image.
        - `scale_factor::Float64`: Scaling factor for resizing the cursor (default = 1.0).

        # Example
        set_cursor_with_image(this, "cursor.png", 10, 10, 2.0)  # Scales up by 2x
    """
    function set_cursor_with_image(this::Input, imagePath::String, x::Int, y::Int, scale_factor::Float64=1.0)
        surface = nothing
        if haskey(JulGame.IMAGE_CACHE, get_comma_separated_path(imagePath))
            raw_data = JulGame.IMAGE_CACHE[get_comma_separated_path(imagePath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading cursor from cache")
                @debug("comma separated path: ", get_comma_separated_path(imagePath))
                surface = SDL2.IMG_Load_RW(rw, 1)
            end
        else
            @debug("loading cursor from disk")
            surface = SDL2.IMG_Load(pointer(joinpath(JulGame.BasePath, "assets", "images", imagePath)))
        end
        @debug "Loading image from disk $(fullPath) for sprite, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        if surface == C_NULL
            @error "Failed to load cursor image: $(unsafe_string(SDL2.SDL_GetError()))"
            return
        end

        # Get original width and height
        original_width = unsafe_load(surface).w
        original_height = unsafe_load(surface).h

        # Calculate new dimensions
        new_width = Int(round(original_width * scale_factor))
        new_height = Int(round(original_height * scale_factor))

        # Scale the hotspot position
        new_x = Int(round(x * scale_factor))
        new_y = Int(round(y * scale_factor))

        # Create a new surface for the scaled image
        scaled_surface = SDL2.SDL_CreateRGBSurface(0, new_width, new_height, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)

        if scaled_surface == C_NULL
            @error "Failed to create scaled surface: $(unsafe_string(SDL2.SDL_GetError()))"
            SDL2.SDL_FreeSurface(surface)
            return
        end

        # Scale the image onto the new surface
        SDL2.SDL_BlitScaled(surface, C_NULL, scaled_surface, C_NULL)

        # Create cursor from the scaled surface with adjusted hotspot
        cursor = SDL2.SDL_CreateColorCursor(scaled_surface, new_x, new_y)

        if cursor != C_NULL
            set_cursor(cursor)
            this.defaultCursor = cursor
            @debug "Cursor set successfully! Scaled by $(scale_factor)x, Hotspot: ($new_x, $new_y)"
        else
            @error "Issue loading cursor: $(unsafe_string(SDL2.SDL_GetError()))"
        end

        # Free surfaces to avoid memory leaks
        SDL2.SDL_FreeSurface(surface)
        SDL2.SDL_FreeSurface(scaled_surface)

        return cursor
    end

    function set_cursor_with_image(imagePath::String, x::Int, y::Int, scale_factor::Float64=1.0)
        set_cursor_with_image(MAIN.input, imagePath, x, y, scale_factor)
    end

    function set_cursor(cursor)
        SDL2.SDL_SetCursor(cursor)
    end

    function create_cursor_bank(this::Input)
        this.cursorBank["arrow"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_ARROW)
        this.cursorBank["ibeam"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_IBEAM)
        this.cursorBank["wait"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_WAIT)
        this.cursorBank["crosshair"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_CROSSHAIR)
        this.cursorBank["waitarrow"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_WAITARROW)
        this.cursorBank["sizeall"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEALL)
        this.cursorBank["sizenesw"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENESW)
        this.cursorBank["sizenwse"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENWSE)
        this.cursorBank["sizewe"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEWE)
        this.cursorBank["sizens"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENS)
        this.cursorBank["no"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_NO)
        this.cursorBank["hand"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_HAND)
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')

        # Split the path into components
        parts = split(normalized_path, '/')

        result = join(parts[1:end], ",")

        return result
    end