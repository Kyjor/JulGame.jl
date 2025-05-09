"""
    This module contains functions for cropping and modifying sprites. It's as PoC at the moment but will need to be generalized.
"""
module ImageFXModule
    using ..FX.JulGame
    import ..Math
    import ..FX.SpriteModule
    using ..FX.SDL2  # Use SDL2 directly

    export crop_top_down
    """
    Crops a sprite from top to bottom, creating a depleting bar effect.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value
    """
    function crop_top_down(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped height
        croppedHeight = round(Int, originalHeight * percentage)
        
        # For top-down effect with bottom anchoring:
        # We keep the sprite at the bottom and crop from the top down
        # So we start from the bottom of the original height and work up
        yStart = originalHeight - croppedHeight
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, yStart, originalWidth, croppedHeight)
        
        # Set the anchor to bottom so the sprite stays anchored at the bottom when cropped
        sprite.anchor = :bottom
        
        return sprite
    end
    
    export crop_bottom_up
    """
    Crops a sprite from bottom to top, creating a rising bar effect.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value
    """
    function crop_bottom_up(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped height
        croppedHeight = round(Int, originalHeight * percentage)
        
        # Calculate y-offset to keep the sprite anchored at the bottom
        yOffset = originalHeight - croppedHeight
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, yOffset, originalWidth, croppedHeight)
        
        return sprite
    end
    
    export crop_left_right
    """
    Crops a sprite from left to right, creating a horizontal depleting bar effect.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value
    """
    function crop_left_right(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped width
        croppedWidth = round(Int, originalWidth * percentage)
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, 0, croppedWidth, originalHeight)
        
        return sprite
    end
    
    export crop_right_left
    """
    Crops a sprite from right to left, creating a horizontal depleting bar effect.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value
    """
    function crop_right_left(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped width
        croppedWidth = round(Int, originalWidth * percentage)
        
        # Calculate x-offset to keep the sprite anchored at the right
        xOffset = originalWidth - croppedWidth
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(xOffset, 0, croppedWidth, originalHeight)
        
        return sprite
    end
    
    export reset_crop
    """
    Resets a sprite's crop to show the full image.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to reset
    
    # Returns
    - The original sprite with crop reset
    """
    function reset_crop(sprite::SpriteModule.InternalSprite)
        sprite.crop = Math.Vector4(0, 0, sprite.size.x, sprite.size.y)
        return sprite
    end
    
    export crop_top_down_anchored_bottom
    """
    Crops a sprite from top to bottom while keeping it anchored to the bottom.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value and offset
    """
    function crop_top_down_anchored_bottom(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped height
        croppedHeight = round(Int, originalHeight * percentage)
        
        # Calculate y-offset to keep the sprite anchored at the bottom
        # We need to adjust the offset so that the bottom of the cropped sprite
        # stays at the same position as the bottom of the original sprite
        yOffset = (originalHeight - croppedHeight) / 2
        
        # Set the sprite's offset to account for cropping
        sprite.offset = Math.Vector2f(sprite.offset.x, yOffset)
        
        # Create crop Vector4 (x, y, width, height)
        # y starts from the top of the image (0) and extends down by the cropped height
        sprite.crop = Math.Vector4(0, 0, originalWidth, croppedHeight)
        
        return sprite
    end
    
    export crop_top_down_fixed
    """
    Crops a sprite from top to bottom, creating a depleting bar effect that accounts for centering.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value
    """
    function crop_top_down_fixed(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped height
        croppedHeight = round(Int, originalHeight * percentage)
        
        # For a top-down effect with centering compensation:
        # - We take the crop from the bottom of the sprite (higher y values)
        # - y starts from (originalHeight - croppedHeight) and extends down
        yStart = originalHeight - croppedHeight
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, yStart, originalWidth, croppedHeight)
        
        return sprite
    end
    
    export crop_top_down_anchor
    """
    Crops a sprite from top to bottom and adjusts its center to create a proper depleting bar effect.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing how much of the sprite to show (1.0 = full sprite, 0.0 = fully cropped)
    
    # Returns
    - The original sprite with an updated crop value and center
    """
    function crop_top_down_anchor(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Save the original center
        originalCenter = sprite.center
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate cropped height
        croppedHeight = round(Int, originalHeight * percentage)
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, 0, originalWidth, croppedHeight)
        
        # Adjust the center to anchor at the bottom
        # A center value of (0.5, 1.0) means horizontally centered and at the bottom
        sprite.center = Math.Vector2f(0.5, 1.0)
        
        return sprite
    end
    
    export crop_health_bar_top_down
    """
    Creates a depleting health bar effect from top to bottom.
    This is specifically designed to work with the bar shown in the image.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Value between 0.0 and 1.0 representing health percentage
    
    # Returns
    - The original sprite with an updated crop value
    """
    function crop_health_bar_top_down(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # For health bar effect:
        # 1. We start from the bottom of the image (where the blue bar is)
        # 2. The visible height is determined by the health percentage
        # 3. We anchor to the bottom to keep it in place
        
        # Calculate visible height based on percentage
        visibleHeight = round(Int, originalHeight * percentage)
        
        # Calculate y-start to show the bottom portion of the image
        yStart = 0
        
        # Create crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, yStart, originalWidth, visibleHeight)
        
        # Set the anchor to bottom to keep it aligned with the bottom
        sprite.anchor = :bottom
        
        return sprite
    end

    # SDL2 image filter wrappers - simplified to use direct calls
    # These functions work on raw pixel data
    
    """
    Applies a filter that keeps only values above a threshold
    
    # Arguments
    - `src::Vector{UInt8}`: Source pixel data
    - `dest::Vector{UInt8}`: Destination pixel data buffer
    - `length::Int`: Number of bytes to process
    - `threshold::UInt8`: Threshold value
    """
    function binarize_using_threshold(src::Vector{UInt8}, dest::Vector{UInt8}, length::Integer, threshold::UInt8)
        SDL2.SDL_imageFilterBinarizeUsingThreshold(pointer(src), pointer(dest), Cuint(length), Cuint(threshold))
    end
    
    """
    Applies a multiplier to each byte
    
    # Arguments
    - `src::Vector{UInt8}`: Source pixel data
    - `dest::Vector{UInt8}`: Destination pixel data buffer
    - `length::Int`: Number of bytes to process
    - `multiplier::UInt8`: Value to multiply each byte by
    """
    function mult_by_byte(src::Vector{UInt8}, dest::Vector{UInt8}, length::Integer, multiplier::UInt8)
        SDL2.SDL_imageFilterMultByByte(pointer(src), pointer(dest), Cuint(length), Cuint(multiplier))
    end
    
    """
    Clips values to be within a range
    
    # Arguments
    - `src::Vector{UInt8}`: Source pixel data
    - `dest::Vector{UInt8}`: Destination pixel data buffer
    - `length::Int`: Number of bytes to process
    - `min::UInt8`: Minimum value
    - `max::UInt8`: Maximum value
    """
    function clip_to_range(src::Vector{UInt8}, dest::Vector{UInt8}, length::Integer, min::UInt8, max::UInt8)
        SDL2.SDL_imageFilterClipToRange(pointer(src), pointer(dest), Cuint(length), Cuint(min), Cuint(max))
    end
    
    """
    Adds a byte value to each element
    
    # Arguments
    - `src::Vector{UInt8}`: Source pixel data
    - `dest::Vector{UInt8}`: Destination pixel data buffer
    - `length::Int`: Number of bytes to process
    - `byte::UInt8`: Value to add
    """
    function add_byte(src::Vector{UInt8}, dest::Vector{UInt8}, length::Integer, byte::UInt8)
        SDL2.SDL_imageFilterAddByte(pointer(src), pointer(dest), Cuint(length), Cuint(byte))
    end
    
    # Global cache to store original textures for sprites
    const ORIGINAL_SPRITE_CACHE = Dict{String, Ptr{SDL2.LibSDL2.SDL_Surface}}()
    
    export gfx_filter_health_bar
    """
    Creates a health bar using SDL2 GFX image filter functions.
    Uses a cached original image to support both increasing and decreasing health.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to modify
    - `percentage::Float64`: Health percentage (0.0 to 1.0)
    
    # Returns
    - The sprite with modified pixel data
    """
    function gfx_filter_health_bar(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        if sprite.image == C_NULL
            @error "Cannot apply image filter: sprite has no image"
            return sprite
        end
        
        # Create cache key from sprite's image path
        cache_key = sprite.imagePath
        
        # Cache the original surface if not already cached
        if !haskey(ORIGINAL_SPRITE_CACHE, cache_key)
            # Make a backup of the original surface
            original_surface = SDL2.SDL_DuplicateSurface(sprite.image)
            if original_surface == C_NULL
                @error "Failed to duplicate original surface for caching"
                return sprite
            end
            ORIGINAL_SPRITE_CACHE[cache_key] = original_surface
            @debug "Cached original surface for sprite: $cache_key"
        end
        
        # Get the original surface from cache
        original_surface = ORIGINAL_SPRITE_CACHE[cache_key]
        
        # Access the raw pixel data from the SDL_Surface
        surface = unsafe_wrap(Array, original_surface, 10; own = false)[1]
        width = surface.w
        height = surface.h
        pitch = surface.pitch
        format = unsafe_wrap(Array, surface.format, 10; own = false)[1]
        bpp = format.BytesPerPixel
        
        # Create a new surface to work with
        new_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, format.format)
        
        if new_surface == C_NULL
            @error "Failed to create new surface for health bar"
            return sprite
        end
        
        # Copy original surface to new surface
        SDL2.SDL_BlitSurface(original_surface, C_NULL, new_surface, C_NULL)
        
        # Lock the surface to access the pixels
        SDL2.SDL_LockSurface(new_surface)
        
        # Get pixel data as bytes
        pixels_ptr = convert(Ptr{UInt8}, unsafe_load(new_surface).pixels)
        total_bytes = height * width * bpp  # 4      bytes per pixel in RGBA8888
        
        # Create buffer arrays for processing
        src_buffer = Vector{UInt8}(undef, total_bytes)
        dest_buffer = Vector{UInt8}(undef, total_bytes)
        
        # Copy pixel data to our buffer
        unsafe_copyto!(pointer(src_buffer), pixels_ptr, total_bytes)
        
        # Calculate empty portion height
        empty_height = round(Int, height * (1.0 - percentage))
        empty_bytes = empty_height * width * 4
        
        # Copy the buffer to destination first
        dest_buffer .= src_buffer
        
        # Apply GFX filter to the empty portion (top of health bar)
        if empty_bytes > 0
            # Use the threshold filter to make the empty portion transparent
            SDL2.SDL_imageFilterBinarizeUsingThreshold(
                pointer(src_buffer),
                pointer(dest_buffer),
                Cuint(empty_bytes),
                Cuint(1)
            )
            
            # Set alpha channel to zero for the empty portion
            for i in 1:empty_bytes
                if (i % 4) == 0  # Alpha channel (every 4th byte in RGBA)
                    dest_buffer[i] = 0
                end
            end
            
            # For the visible portion, keep the original data
            if empty_bytes < total_bytes
                dest_buffer[(empty_bytes+1):end] .= src_buffer[(empty_bytes+1):end]
            end
        end
        
        # Copy our processed buffer back to the surface
        unsafe_copyto!(pixels_ptr, pointer(dest_buffer), total_bytes)
        
        # Unlock the surface
        SDL2.SDL_UnlockSurface(new_surface)
        
        # Clean up existing texture
        if sprite.texture != C_NULL
            SDL2.SDL_DestroyTexture(sprite.texture)
            sprite.texture = C_NULL
        end
        
        # Clean up previous image
        if sprite.image != C_NULL && sprite.image != original_surface
            SDL2.SDL_FreeSurface(sprite.image)
        end
        
        # Update sprite with new surface
        sprite.image = new_surface
        sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, new_surface)
        
        # Enable alpha blending
        SDL2.SDL_SetTextureBlendMode(sprite.texture, SDL2.SDL_BLENDMODE_BLEND)
        
        return sprite
    end
    
    # Function to clean up the cache when needed
    export clear_sprite_cache
    function clear_sprite_cache()
        for (_, surface) in ORIGINAL_SPRITE_CACHE
            SDL2.SDL_FreeSurface(surface)
        end
        empty!(ORIGINAL_SPRITE_CACHE)
        @debug "Cleared sprite cache"
    end
end
