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
    
    # Advanced health bar implementations using SDL2_gfx
    export create_gradient_health_bar
    """
    Creates a health bar with gradient effects based on health percentage
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to modify
    - `percentage::Float64`: Health percentage (0.0 to 1.0)
    - `low_color::NTuple{3, Int}`: RGB color for low health (Default: red)
    - `high_color::NTuple{3, Int}`: RGB color for high health (Default: green)
    
    # Returns
    - The original sprite with updated pixel data and texture
    """
    function create_gradient_health_bar(sprite::SpriteModule.InternalSprite, percentage::Float64;
                                         low_color::NTuple{3,Int}=(255,0,0), 
                                         high_color::NTuple{3,Int}=(0,255,0))
        if sprite.image == C_NULL
            @error "Cannot create gradient health bar: sprite has no image"
            return sprite
        end
        
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Access the raw pixel data from the SDL_Surface
        surface = unsafe_wrap(Array, sprite.image, 10; own = false)[1]
        pixels_ptr = surface.pixels
        pixels_format = surface.format
        format = unsafe_wrap(Array, pixels_format, 10; own = false)[1]
        bytes_per_pixel = format.BytesPerPixel
        width = surface.w
        height = surface.h
        pitch = surface.pitch
        
        # Calculate the height based on percentage
        visible_height = round(Int, height * percentage)
        
        # Create a new SDL_Surface for the modified pixels
        new_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 
                                                        Int32(format.BitsPerPixel), 
                                                        format.format)
        
        if new_surface == C_NULL
            @error "Failed to create new surface for health bar"
            return sprite
        end
        
        new_surface_array = unsafe_wrap(Array, new_surface, 10; own = false)
        new_pixels_ptr = new_surface_array[1].pixels
        
        # Calculate colors based on percentage
        # Interpolate between low_color and high_color
        r = round(Int, low_color[1] * (1.0 - percentage) + high_color[1] * percentage)
        g = round(Int, low_color[2] * (1.0 - percentage) + high_color[2] * percentage)
        b = round(Int, low_color[3] * (1.0 - percentage) + high_color[3] * percentage)
        
        # Fill the new surface with a background color (dark gray)
        # Use Ref to get a pointer to the format
        format_ptr = pixels_format
        SDL2.SDL_FillRect(new_surface, C_NULL, SDL2.SDL_MapRGB(format_ptr, 50, 50, 50))
        
        # Create a rect for the visible part of the health bar
        visible_rect = Ref(SDL2.SDL_Rect(0, height - visible_height, width, visible_height))
        
        # Fill the visible part with the interpolated color
        SDL2.SDL_FillRect(new_surface, visible_rect, SDL2.SDL_MapRGB(format_ptr, UInt8(r), UInt8(g), UInt8(b)))
        
        # Add a highlight effect at the top of the bar
        if visible_height > 2
            highlight_rect = Ref(SDL2.SDL_Rect(1, height - visible_height + 1, width - 2, 2))
            highlight_color = SDL2.SDL_MapRGB(format_ptr, 
                UInt8(min(r + 40, 255)), 
                UInt8(min(g + 40, 255)), 
                UInt8(min(b + 40, 255)))
            SDL2.SDL_FillRect(new_surface, highlight_rect, highlight_color)
        end
        
        # Add a shadow effect at the bottom of the visible part
        if visible_height > 4
            shadow_rect = Ref(SDL2.SDL_Rect(1, height - 4, width - 2, 2))
            shadow_color = SDL2.SDL_MapRGB(format_ptr, 
                UInt8(max(r - 40, 0)), 
                UInt8(max(g - 40, 0)), 
                UInt8(max(b - 40, 0)))
            SDL2.SDL_FillRect(new_surface, shadow_rect, shadow_color)
        end
        
        # Clean up previous texture if it exists
        if sprite.texture != C_NULL
            SDL2.SDL_DestroyTexture(sprite.texture)
        end
        
        # Clean up previous image if it exists
        if sprite.image != C_NULL
            SDL2.SDL_FreeSurface(sprite.image)
        end
        
        # Set the new image and create a new texture
        sprite.image = new_surface
        sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, new_surface)
        
        # Set the sprite's size
        sprite.size = Math.Vector2(width, height)
        
        # Update the color
        SpriteModule.Component.set_color(sprite)
        
        return sprite
    end
    
    export create_dynamic_health_bar
    """
    Creates a health bar with dynamic effects based on health percentage
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to modify
    - `percentage::Float64`: Health percentage (0.0 to 1.0)
    - `critical_threshold::Float64`: Threshold below which health is considered critical (Default: 0.3)
    
    # Returns
    - The original sprite with updated pixel data and texture
    """
    function create_dynamic_health_bar(sprite::SpriteModule.InternalSprite, percentage::Float64;
                                      critical_threshold::Float64=0.3)
        if sprite.image == C_NULL
            @error "Cannot create dynamic health bar: sprite has no image"
            return sprite
        end
        
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Access the raw pixel data from the SDL_Surface
        surface = unsafe_wrap(Array, sprite.image, 10; own = false)[1]
        pixels_ptr = surface.pixels
        pixels_format = surface.format
        format = unsafe_wrap(Array, pixels_format, 10; own = false)[1]
        bytes_per_pixel = format.BytesPerPixel
        width = surface.w
        height = surface.h
        pitch = surface.pitch
        
        # Calculate the height based on percentage
        visible_height = round(Int, height * percentage)
        
        # Create a new SDL_Surface for the modified pixels
        new_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 
                                                        Int32(format.BitsPerPixel), 
                                                        format.format)
        
        if new_surface == C_NULL
            @error "Failed to create new surface for health bar"
            return sprite
        end
        
        new_surface_array = unsafe_wrap(Array, new_surface, 10; own = false)
        new_pixels_ptr = new_surface_array[1].pixels
        
        # Get proper format pointer
        format_ptr = pixels_format
        
        # Fill the new surface with a background color (black with some transparency)
        bg_color = SDL2.SDL_MapRGBA(format_ptr, 0, 0, 0, 200)
        SDL2.SDL_FillRect(new_surface, C_NULL, bg_color)
        
        # Determine the color based on health percentage
        # Green > Yellow > Red as health decreases
        r, g, b = 0, 0, 0
        
        if percentage > 0.6
            # Green to Yellow transition
            g = 255
            r = UInt8(255 * (1.0 - (percentage - 0.6) / 0.4))
        elseif percentage > 0.3
            # Yellow to Red transition
            r = 255
            g = UInt8(255 * ((percentage - 0.3) / 0.3))
        else
            # Red, possibly with pulsing effect for critical health
            r = 255
            g = 0
            
            # Add pulsing effect for critical health
            if percentage < critical_threshold
                # Make the bar pulse by modulating its brightness
                # This would normally be done based on time, but we'll use percentage as a proxy
                pulse_factor = abs(sin(percentage * 10)) * 0.3 + 0.7
                r = UInt8(r * pulse_factor)
            end
        end
        
        # Create a rect for the visible part of the health bar
        visible_rect = Ref(SDL2.SDL_Rect(0, height - visible_height, width, visible_height))
        
        # Fill the visible part with the color
        bar_color = SDL2.SDL_MapRGB(format_ptr, UInt8(r), UInt8(g), UInt8(b))
        SDL2.SDL_FillRect(new_surface, visible_rect, bar_color)
        
        # Add segmentation to the health bar (like notches or segments)
        segment_count = 10
        segment_height = height / segment_count
        segment_color = SDL2.SDL_MapRGBA(format_ptr, 0, 0, 0, 50)
        
        for i in 1:segment_count-1
            segment_y = round(Int, i * segment_height)
            if segment_y < visible_height
                segment_rect = Ref(SDL2.SDL_Rect(0, height - segment_y, width, 1))
                SDL2.SDL_FillRect(new_surface, segment_rect, segment_color)
            end
        end
        
        # Add a border
        # Use boxRGBA instead of rectangleRGBA to avoid direct renderer access
        SDL2.LibSDL2.boxRGBA(JulGame.Renderer, 0, 0, width-1, height-1, 50, 50, 50, 255)
        SDL2.LibSDL2.rectangleRGBA(JulGame.Renderer, 0, 0, width-1, height-1, 255, 255, 255, 255)
        
        # Add a highlight effect at the top of the visible bar
        if visible_height > 3
            highlight_rect = Ref(SDL2.SDL_Rect(1, height - visible_height + 1, width - 2, 2))
            highlight_color = SDL2.SDL_MapRGBA(format_ptr, 
                UInt8(min(r + 40, 255)), 
                UInt8(min(g + 40, 255)), 
                UInt8(min(b + 40, 255)),
                230)
            SDL2.SDL_FillRect(new_surface, highlight_rect, highlight_color)
        end
        
        # Clean up previous texture if it exists
        if sprite.texture != C_NULL
            SDL2.SDL_DestroyTexture(sprite.texture)
        end
        
        # Clean up previous image if it exists
        if sprite.image != C_NULL && sprite.image != new_surface
            SDL2.SDL_FreeSurface(sprite.image)
        end
        
        # Set the new image and create a new texture
        sprite.image = new_surface
        sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, new_surface)
        
        # Set the sprite's size
        sprite.size = Math.Vector2(width, height)
        
        # Update the color
        SpriteModule.Component.set_color(sprite)
        
        # Set anchor to bottom to keep the health bar positioned correctly
        sprite.anchor = :bottom
        
        return sprite
    end

    export simple_health_bar_crop
    """
    Simply crops the sprite based on health percentage, keeping the bar in place.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to crop
    - `percentage::Float64`: Health percentage (0.0 to 1.0)
    
    # Returns
    - The sprite with an updated crop value
    """
    function simple_health_bar_crop(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        # Get original sprite dimensions
        originalWidth = sprite.size.x
        originalHeight = sprite.size.y
        
        # Calculate visible height based on percentage
        visibleHeight = round(Int, originalHeight * percentage)
        
        # For bottom-up health bar, set crop from the bottom of the image
        yStart = originalHeight - visibleHeight
        
        # Create simple crop Vector4 (x, y, width, height)
        sprite.crop = Math.Vector4(0, yStart, originalWidth, visibleHeight)
        
        # Keep everything else the same - no color changes, no fancy effects
        return sprite
    end

    export alpha_mask_health_bar
    """
    Creates a health bar effect by making a portion of the sprite transparent.
    
    # Arguments
    - `sprite::SpriteModule.InternalSprite`: The sprite to modify
    - `percentage::Float64`: Health percentage (0.0 to 1.0)
    
    # Returns
    - The sprite with modified alpha values
    """
    function alpha_mask_health_bar(sprite::SpriteModule.InternalSprite, percentage::Float64)
        percentage = clamp(percentage, 0.0, 1.0)
        
        if sprite.image == C_NULL
            @error "Cannot apply alpha mask: sprite has no image"
            return sprite
        end
        
        # Access the raw pixel data from the SDL_Surface
        surface = unsafe_wrap(Array, sprite.image, 10; own = false)[1]
        width = surface.w
        height = surface.h
        format = surface.format
        
        # Create a new surface with alpha support
        new_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        
        if new_surface == C_NULL
            @error "Failed to create new surface for health bar"
            return sprite
        end
        
        # Copy the original surface to the new one
        SDL2.SDL_BlitSurface(sprite.image, C_NULL, new_surface, C_NULL)
        
        # Calculate the height boundary for transparency
        transparent_start = round(Int, height * percentage)
        
        # Lock the surface to access the pixels
        SDL2.SDL_LockSurface(new_surface)
        
        # Get the pixel data
        pixels = unsafe_wrap(Array, convert(Ptr{UInt32}, unsafe_load(new_surface).pixels), (width, height))
        
        # Loop through the pixels and set alpha = 0 for the portion we want to make transparent
        for y in 1:transparent_start
            for x in 1:width
                # Set alpha to 0 (completely transparent) for this pixel
                # We preserve RGB values but set alpha to 0
                # RGBA is stored as 0xAABBGGRR in memory
                pixels[x, y] = pixels[x, y] & 0x00FFFFFF
            end
        end
        
        # Unlock the surface
        SDL2.SDL_UnlockSurface(new_surface)
        
        # Clean up existing texture
        if sprite.texture != C_NULL
            SDL2.SDL_DestroyTexture(sprite.texture)
            sprite.texture = C_NULL
        end
        
        # Clean up previous image
        if sprite.image != C_NULL && sprite.image != new_surface
            SDL2.SDL_FreeSurface(sprite.image)
        end
        
        # Update sprite with new surface
        sprite.image = new_surface
        sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, new_surface)
        
        # Make sure the sprite's texture has alpha blending enabled
        SDL2.SDL_SetTextureBlendMode(sprite.texture, SDL2.SDL_BLENDMODE_BLEND)
        
        return sprite
    end

    export gfx_filter_health_bar
    """
    Creates a health bar using SDL2 GFX image filter functions.
    
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
        
        # Access the raw pixel data from the SDL_Surface
        surface = unsafe_wrap(Array, sprite.image, 10; own = false)[1]
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
        SDL2.SDL_BlitSurface(sprite.image, C_NULL, new_surface, C_NULL)
        
        # Lock the surface to access the pixels
        SDL2.SDL_LockSurface(new_surface)
        
        # Get pixel data as bytes
        pixels_ptr = convert(Ptr{UInt8}, unsafe_load(new_surface).pixels)
        total_bytes = height * width * bpp  # 4 bytes per pixel in RGBA8888
        
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
        if sprite.image != C_NULL && sprite.image != new_surface
            SDL2.SDL_FreeSurface(sprite.image)
        end
        
        # Update sprite with new surface
        sprite.image = new_surface
        sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, new_surface)
        
        # Enable alpha blending
        SDL2.SDL_SetTextureBlendMode(sprite.texture, SDL2.SDL_BLENDMODE_BLEND)
        
        return sprite
    end
end
