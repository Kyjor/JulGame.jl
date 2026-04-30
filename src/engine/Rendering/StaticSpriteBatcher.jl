module StaticSpriteBatcherModule
using ..JulGame
using ..JulGame.Math

export BatchedLayer, batch_static_sprites, render_batched_layer, cleanup_batched_layers, mark_layer_for_rebatch

"""
    BatchedLayer

Holds a batched texture for a specific sprite layer.
Automatically chunks textures if they exceed maximum size.
"""
mutable struct BatchedLayer
    layer::Int
    textures::Vector{Ptr{SDL2.SDL_Texture}}
    texturesBounds::Vector{Math.Vector4}  # x, y, width, height for each chunk
    spriteHashes::Vector{UInt64}  # Track sprite state to detect changes
    needsRebatch::Bool
    debugOffset::Math.Vector2f  # Manual offset for debugging alignment issues
    
    function BatchedLayer(layer::Int)
        this = new()
        this.layer = layer
        this.textures = Ptr{SDL2.SDL_Texture}[]
        this.texturesBounds = Math.Vector4[]
        this.spriteHashes = UInt64[]
        this.needsRebatch = true
        this.debugOffset = Math.Vector2f(0.0, 0.0)
        return this
    end
end

# Maximum texture size before chunking (most GPUs support 8192+)
const MAX_TEXTURE_SIZE = 8192

"""
    calculate_sprite_hash(sprite::JulGame.Component.SpriteModule.InternalSprite)

Calculate a hash of sprite properties to detect changes.
"""
function calculate_sprite_hash(sprite::JulGame.Component.SpriteModule.InternalSprite)
    return hash((
        sprite.imagePath,
        sprite.parent.transform.position.x,
        sprite.parent.transform.position.y,
        sprite.parent.transform.scale.x,
        sprite.parent.transform.scale.y,
        sprite.rotation,
        sprite.color,
        sprite.crop,
        sprite.isFlipped,
        sprite.offset.x,
        sprite.offset.y,
        sprite.layer
    ))
end

"""
    get_static_sprites_by_layer()

Collect all static sprites from the scene, grouped by layer.
Returns a Dict{Int, Vector{InternalSprite}}.
"""
function get_static_sprites_by_layer()
    layer_sprites = Dict{Int, Vector{Any}}()
    
    for entity in JulGame.MAIN.scene.entities
        sprite = entity.sprite
        if sprite != C_NULL && sprite !== nothing && sprite.isStatic
            layer = sprite.layer
            if !haskey(layer_sprites, layer)
                layer_sprites[layer] = []
            end
            push!(layer_sprites[layer], sprite)
        end
    end
    
    return layer_sprites
end

"""
    calculate_bounding_box(sprites::Vector)

Calculate the minimal bounding box that contains all sprites.
Returns (min_x, min_y, max_x, max_y) in world coordinates.
"""
function calculate_bounding_box(sprites::Vector)
    if isempty(sprites)
        return (0.0, 0.0, 0.0, 0.0)
    end
    
    min_x = Inf
    min_y = Inf
    max_x = -Inf
    max_y = -Inf
    
    SCALE_UNITS = JulGame.SCALE_UNITS
    
    for sprite in sprites
        entity = sprite.parent
        pos = entity.transform.position
        scale = entity.transform.scale
        
        # Calculate sprite size in world units
        cropWidth = (sprite.crop == Math.Vector4(0, 0, 0, 0) || sprite.crop == C_NULL) ? sprite.size.x : sprite.crop.z
        cropHeight = (sprite.crop == Math.Vector4(0, 0, 0, 0) || sprite.crop == C_NULL) ? sprite.size.y : sprite.crop.t
        
        if sprite.pixelsPerUnit == 0
            sprite_width = cropWidth * scale.x / 64.0
            sprite_height = cropHeight * scale.y / 64.0
        else
            ppu = sprite.pixelsPerUnit > 0 ? sprite.pixelsPerUnit : JulGame.PIXELS_PER_UNIT
            sprite_width = cropWidth * scale.x / ppu
            sprite_height = cropHeight * scale.y / ppu
        end
        
        # Calculate base position
        base_x = pos.x + sprite.offset.x
        base_y = pos.y + sprite.offset.y
        
        # Calculate sprite bounds based on anchor (matching Sprite.jl anchor logic)
        # The anchor determines where the transform position is relative to the sprite
        if sprite.anchor == :center
            x1 = base_x - sprite_width / 2
            y1 = base_y - sprite_height / 2
        elseif sprite.anchor == :top
            x1 = base_x - sprite_width / 2
            y1 = base_y
        elseif sprite.anchor == :bottom
            x1 = base_x - sprite_width / 2
            y1 = base_y - sprite_height
        elseif sprite.anchor == :left
            x1 = base_x
            y1 = base_y - sprite_height / 2
        elseif sprite.anchor == :right
            x1 = base_x - sprite_width
            y1 = base_y - sprite_height / 2
        elseif sprite.anchor == :topleft
            x1 = base_x
            y1 = base_y
        elseif sprite.anchor == :topright
            x1 = base_x - sprite_width
            y1 = base_y
        elseif sprite.anchor == :bottomleft
            x1 = base_x
            y1 = base_y - sprite_height
        elseif sprite.anchor == :bottomright
            x1 = base_x - sprite_width
            y1 = base_y - sprite_height
        else
            # Default to center if unknown anchor
            x1 = base_x - sprite_width / 2
            y1 = base_y - sprite_height / 2
        end
        
        x2 = x1 + sprite_width
        y2 = y1 + sprite_height
        
        min_x = min(min_x, x1)
        min_y = min(min_y, y1)
        max_x = max(max_x, x2)
        max_y = max(max_y, y2)
    end
    
    return (min_x, min_y, max_x, max_y)
end

"""
    create_batched_texture_for_sprites(sprites::Vector, bounds::NTuple{4, Float64})

Create a single texture containing all sprites.
Returns the texture pointer or C_NULL on failure.
"""
function create_batched_texture_for_sprites(sprites::Vector, bounds::NTuple{4, Float64})
    min_x, min_y, max_x, max_y = bounds
    
    # Calculate texture dimensions in pixels
    SCALE_UNITS = JulGame.SCALE_UNITS
    width = ceil(Int32, (max_x - min_x) * SCALE_UNITS)
    height = ceil(Int32, (max_y - min_y) * SCALE_UNITS)
    
    # Clamp to max size
    width = min(width, MAX_TEXTURE_SIZE)
    height = min(height, MAX_TEXTURE_SIZE)
    
    if width <= 0 || height <= 0
        @warn "Invalid texture dimensions: $(width)x$(height)"
        return C_NULL
    end
    
    @debug "Creating batched texture: $(width)x$(height) for $(length(sprites)) sprites"
    
    # Create render target texture
    texture = SDL2.SDL_CreateTexture(
        JulGame.Renderer,
        SDL2.SDL_PIXELFORMAT_RGBA8888,
        SDL2.SDL_TEXTUREACCESS_TARGET,
        width,
        height
    )
    
    if texture == C_NULL
        @error "Failed to create batched texture: $(unsafe_string(SDL2.SDL_GetError()))"
        return C_NULL
    end
    
    # Enable transparency
    SDL2.SDL_SetTextureBlendMode(texture, SDL2.SDL_BLENDMODE_BLEND)
    
    # Set as render target
    SDL2.SDL_SetRenderTarget(JulGame.Renderer, texture)
    
    # Clear with transparent background
    SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 0, 0, 0)
    SDL2.SDL_RenderClear(JulGame.Renderer)
    
    # Render each sprite to the texture
    for sprite in sprites
        render_sprite_to_texture(sprite, min_x, min_y, SCALE_UNITS)
    end
    
    # Reset render target to screen
    SDL2.SDL_SetRenderTarget(JulGame.Renderer, C_NULL)
    
    return texture
end

"""
    render_sprite_to_texture(sprite, offset_x, offset_y, scale_units)

Render a single sprite to the current render target (batched texture).
"""
function render_sprite_to_texture(sprite, offset_x::Float64, offset_y::Float64, scale_units)
    # Ensure sprite has a texture
    if sprite.texture == C_NULL && sprite.image != C_NULL
        sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, sprite.image)
        JulGame.Component.set_color(sprite)
    end
    
    if sprite.texture == C_NULL
        return
    end
    
    # Set color modulation
    SDL2.SDL_SetTextureColorMod(
        sprite.texture,
        UInt8(clamp(sprite.color[1], 0, 255)),
        UInt8(clamp(sprite.color[2], 0, 255)),
        UInt8(clamp(sprite.color[3], 0, 255))
    )
    SDL2.SDL_SetTextureAlphaMod(sprite.texture, UInt8(clamp(sprite.color[4], 0, 255)))
    
    # Calculate sprite position and size
    entity = sprite.parent
    pos = entity.transform.position
    scale = entity.transform.scale
    
    # Calculate size
    cropWidth = (sprite.crop == Math.Vector4(0, 0, 0, 0) || sprite.crop == C_NULL) ? sprite.size.x : sprite.crop.z
    cropHeight = (sprite.crop == Math.Vector4(0, 0, 0, 0) || sprite.crop == C_NULL) ? sprite.size.y : sprite.crop.t
    
    if sprite.pixelsPerUnit == 0
        scaledWidth = cropWidth * scale.x * scale_units / 64.0
        scaledHeight = cropHeight * scale.y * scale_units / 64.0
    else
        ppu = sprite.pixelsPerUnit > 0 ? sprite.pixelsPerUnit : JulGame.PIXELS_PER_UNIT
        scaleFactor = scale_units / ppu
        scaledWidth = cropWidth * scaleFactor * scale.x
        scaledHeight = cropHeight * scaleFactor * scale.y
    end
    
    # Match Sprite.jl's positioning logic EXACTLY
    # Step 1: Calculate base position in pixels (relative to texture origin)
    adjustedX = (pos.x + sprite.offset.x) * scale_units - offset_x * scale_units
    adjustedY = (pos.y + sprite.offset.y) * scale_units - offset_y * scale_units
    
    # Step 2: Apply anchor positioning (EXACTLY as Sprite.jl does it)
    # The anchor offset is based on the difference between scaledWidth/Height and SCALE_UNITS * scale
    centeredX = adjustedX
    centeredY = adjustedY
    
    if sprite.anchor == :center
        centeredX -= (scaledWidth - scale_units * scale.x) / 2
        centeredY -= (scaledHeight - scale_units * scale.y) / 2
    elseif sprite.anchor == :top
        centeredX -= (scaledWidth - scale_units * scale.x) / 2
        # No Y adjustment
    elseif sprite.anchor == :bottom
        centeredX -= (scaledWidth - scale_units * scale.x) / 2
        centeredY -= (scaledHeight - scale_units * scale.y)
    elseif sprite.anchor == :left
        # No X adjustment
        centeredY -= (scaledHeight - scale_units * scale.y) / 2
    elseif sprite.anchor == :right
        centeredX -= (scaledWidth - scale_units * scale.x)
        centeredY -= (scaledHeight - scale_units * scale.y) / 2
    elseif sprite.anchor == :topleft
        # No adjustment
    elseif sprite.anchor == :topright
        centeredX -= (scaledWidth - scale_units * scale.x)
        # No Y adjustment
    elseif sprite.anchor == :bottomleft
        # No X adjustment
        centeredY -= (scaledHeight - scale_units * scale.y)
    elseif sprite.anchor == :bottomright
        centeredX -= (scaledWidth - scale_units * scale.x)
        centeredY -= (scaledHeight - scale_units * scale.y)
    end
    
    # Source rectangle
    srcRect = (sprite.crop == Math.Vector4(0, 0, 0, 0) || sprite.crop == C_NULL) ? 
        C_NULL : 
        Ref(SDL2.SDL_Rect(
            Math.TypeConversions.safe_int32_convert(sprite.crop.x),
            Math.TypeConversions.safe_int32_convert(sprite.crop.y),
            Math.TypeConversions.safe_int32_convert(sprite.crop.z),
            Math.TypeConversions.safe_int32_convert(sprite.crop.t)
        ))
    
    # Destination rectangle
    dstRect = Ref(SDL2.SDL_Rect(
        Math.TypeConversions.safe_int32_convert(round(centeredX)),
        Math.TypeConversions.safe_int32_convert(round(centeredY)),
        Math.TypeConversions.safe_int32_convert(round(scaledWidth)),
        Math.TypeConversions.safe_int32_convert(round(scaledHeight))
    ))
    
    # Rotation center
    calculatedCenter = Math.Vector2(dstRect[].w * (sprite.center.x % 1), dstRect[].h * (sprite.center.y % 1))
    rotationCenter = Ref(SDL2.SDL_Point(
        Math.TypeConversions.safe_int32_convert(round(calculatedCenter.x)),
        Math.TypeConversions.safe_int32_convert(round(calculatedCenter.y))
    ))
    
    # Render to texture
    SDL2.SDL_RenderCopyEx(
        JulGame.Renderer,
        sprite.texture,
        srcRect,
        dstRect,
        sprite.rotation,
        rotationCenter,
        sprite.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE
    )
end

"""
    batch_static_sprites(scene::JulGame.SceneModule.Scene)

Batch all static sprites in the scene by layer.
Returns a Dict{Int, BatchedLayer}.
"""
function batch_static_sprites(scene::JulGame.SceneModule.Scene)
    @debug "Batching static sprites..."
    
    # Get sprites grouped by layer
    layer_sprites = get_static_sprites_by_layer()
    
    if isempty(layer_sprites)
        @debug "No static sprites to batch"
        return Dict{Int, BatchedLayer}()
    end
    
    batched_layers = Dict{Int, BatchedLayer}()
    
    for (layer, sprites) in layer_sprites
        @debug "Batching layer $(layer) with $(length(sprites)) sprites"
        
        batched_layer = BatchedLayer(layer)
        
        # Calculate bounding box
        bounds = calculate_bounding_box(sprites)
        min_x, min_y, max_x, max_y = bounds
        
        if max_x - min_x <= 0 || max_y - min_y <= 0
            @warn "Invalid bounds for layer $(layer), skipping"
            continue
        end
        
        # Check if we need to chunk
        texture_width = ceil(Int32, (max_x - min_x) * JulGame.SCALE_UNITS)
        texture_height = ceil(Int32, (max_y - min_y) * JulGame.SCALE_UNITS)
        
        if texture_width > MAX_TEXTURE_SIZE || texture_height > MAX_TEXTURE_SIZE
            @debug "Layer $(layer) exceeds max texture size, will need chunking in future"
            # TODO: Implement chunking for very large layers
            # For now, clamp to max size (sprites outside will be cut off)
        end
        
        # Create batched texture
        texture = create_batched_texture_for_sprites(sprites, bounds)
        
        if texture != C_NULL
            push!(batched_layer.textures, texture)
            push!(batched_layer.texturesBounds, Math.Vector4(min_x, min_y, max_x - min_x, max_y - min_y))
            
            # Store sprite hashes for change detection
            for sprite in sprites
                push!(batched_layer.spriteHashes, calculate_sprite_hash(sprite))
            end
            
            batched_layer.needsRebatch = false
            batched_layers[layer] = batched_layer
            
            @debug "Successfully batched layer $(layer)"
        else
            @error "Failed to create batched texture for layer $(layer)"
        end
    end
    
    @debug "Batching complete: $(length(batched_layers)) layers batched"
    return batched_layers
end

"""
    render_batched_layer(batched_layer::BatchedLayer, camera)

Render a batched layer with camera offset and culling.
"""
function render_batched_layer(batched_layer::BatchedLayer, camera)
    if isempty(batched_layer.textures)
        return
    end
    
    S = JulGame.pixels_per_world_unit(camera)
    
    # Calculate camera offset
    cameraDiff = camera !== nothing ? 
        Math.Vector2((camera.position.x + camera.offset.x) * S, (camera.position.y + camera.offset.y) * S) : 
        Math.Vector2(0, 0)
    
    cameraSize = camera !== nothing ? camera.size : Math.Vector2(0, 0)
    cameraPosition = camera !== nothing ? camera.position : Math.Vector2f(0, 0)
    
    for i in eachindex(batched_layer.textures)
        texture = batched_layer.textures[i]
        bounds = batched_layer.texturesBounds[i]
        
        # bounds: x, y, width, height (in world units)
        world_x = bounds.x
        world_y = bounds.y
        world_width = bounds.z
        world_height = bounds.t
        
        # Culling check - skip if batched layer is completely off screen
        if camera !== nothing && cameraSize.x > 0 && cameraSize.y > 0
            if world_x + world_width < cameraPosition.x || 
               world_y + world_height < cameraPosition.y ||
               world_x > cameraPosition.x + cameraSize.x / S ||
               world_y > cameraPosition.y + cameraSize.y / S
                @debug "Culling batched layer $(batched_layer.layer) chunk $(i) - off screen"
                continue
            end
        end
        
        # Convert to screen coordinates
        screen_x = world_x * S - cameraDiff.x + batched_layer.debugOffset.x
        screen_y = world_y * S - cameraDiff.y + batched_layer.debugOffset.y
        screen_width = world_width * S
        screen_height = world_height * S
        
        # Source rect (entire texture)
        src_rect = Ref(SDL2.SDL_Rect(
            0, 0,
            Math.TypeConversions.safe_int32_convert(ceil(screen_width)),
            Math.TypeConversions.safe_int32_convert(ceil(screen_height))
        ))
        
        # Destination rect
        dest_rect = Ref(SDL2.SDL_Rect(
            Math.TypeConversions.safe_int32_convert(round(screen_x)),
            Math.TypeConversions.safe_int32_convert(round(screen_y)),
            Math.TypeConversions.safe_int32_convert(ceil(screen_width)),
            Math.TypeConversions.safe_int32_convert(ceil(screen_height))
        ))
        
        # Render
        SDL2.SDL_RenderCopy(
            JulGame.Renderer,
            texture,
            src_rect,
            dest_rect
        )
    end
end

"""
    cleanup_batched_layers(batched_layers::Dict{Int, BatchedLayer})

Clean up all batched textures to prevent memory leaks.
"""
function cleanup_batched_layers(batched_layers::Dict)
    @debug "Cleaning up batched layers..."
    
    for (layer, batched_layer) in batched_layers
        for texture in batched_layer.textures
            if texture != C_NULL
                SDL2.SDL_DestroyTexture(texture)
            end
        end
        empty!(batched_layer.textures)
        empty!(batched_layer.texturesBounds)
        empty!(batched_layer.spriteHashes)
    end
    
    empty!(batched_layers)
    @debug "Batched layers cleaned up"
end

"""
    mark_layer_for_rebatch(scene::JulGame.SceneModule.Scene, layer::Int)

Mark a specific layer for rebatching on the next frame.
"""
function mark_layer_for_rebatch(scene::JulGame.SceneModule.Scene, layer::Int)
    if hasfield(typeof(scene), :batchedLayers) && haskey(scene.batchedLayers, layer)
        scene.batchedLayers[layer].needsRebatch = true
        @debug "Marked layer $(layer) for rebatch"
    end
end

"""
    check_and_rebatch_if_needed(scene::JulGame.SceneModule.Scene)

Check if any static sprites have changed and rebatch if necessary.
"""
function check_and_rebatch_if_needed(scene::JulGame.SceneModule.Scene)
    if !hasfield(typeof(scene), :batchedLayers) || isempty(scene.batchedLayers)
        return
    end
    
    layer_sprites = get_static_sprites_by_layer()
    
    for (layer, batched_layer) in scene.batchedLayers
        if batched_layer.needsRebatch
            continue  # Already marked for rebatch
        end
        
        # Check if sprite count changed
        if !haskey(layer_sprites, layer) && !isempty(batched_layer.textures)
            batched_layer.needsRebatch = true
            @debug "Layer $(layer) needs rebatch: all sprites removed"
            continue
        end
        
        if haskey(layer_sprites, layer)
            sprites = layer_sprites[layer]
            
            # Check if sprite count changed
            if length(sprites) != length(batched_layer.spriteHashes)
                batched_layer.needsRebatch = true
                @debug "Layer $(layer) needs rebatch: sprite count changed"
                continue
            end
            
            # Check if any sprite properties changed
            for (i, sprite) in enumerate(sprites)
                current_hash = calculate_sprite_hash(sprite)
                if i <= length(batched_layer.spriteHashes) && current_hash != batched_layer.spriteHashes[i]
                    batched_layer.needsRebatch = true
                    @debug "Layer $(layer) needs rebatch: sprite $(i) changed"
                    break
                end
            end
        end
    end
    
    # Rebatch layers that need it
    for (layer, batched_layer) in scene.batchedLayers
        if batched_layer.needsRebatch
            @debug "Rebatching layer $(layer)"
            
            # Clean up old textures
            for texture in batched_layer.textures
                if texture != C_NULL
                    SDL2.SDL_DestroyTexture(texture)
                end
            end
            empty!(batched_layer.textures)
            empty!(batched_layer.texturesBounds)
            empty!(batched_layer.spriteHashes)
            
            # Rebatch
            if haskey(layer_sprites, layer)
                sprites = layer_sprites[layer]
                bounds = calculate_bounding_box(sprites)
                texture = create_batched_texture_for_sprites(sprites, bounds)
                
                if texture != C_NULL
                    push!(batched_layer.textures, texture)
                    push!(batched_layer.texturesBounds, Math.Vector4(bounds[1], bounds[2], bounds[3] - bounds[1], bounds[4] - bounds[2]))
                    
                    for sprite in sprites
                        push!(batched_layer.spriteHashes, calculate_sprite_hash(sprite))
                    end
                    
                    batched_layer.needsRebatch = false
                end
            end
        end
    end
end

end # module

