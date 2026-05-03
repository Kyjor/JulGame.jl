module StaticSpriteBatcherModule
using ..JulGame
using ..JulGame.Math

export BatchedLayer, batch_static_sprites, render_batched_layer, cleanup_batched_layers, mark_layer_for_rebatch

"""
    BatchedLayer

Holds a batched texture for a specific sprite layer.
Automatically chunks textures if they exceed maximum size.
"""
# Trim-native math: avoid `getglobal(Math, :Vector4)` / alias constructors in inferrable paths.
const _BATCH_V4_ZERO_I32 = Math._Vector4{Int32}(0, 0, 0, 0)
const _STATIC_BATCH_DEFAULT_PPU = 16

@inline function _batch_safe_round_i32(x::Float64)::Int32
    return Math.TypeConversions.safe_int32_convert(Base.round(x)::Float64)
end

mutable struct BatchedLayer
    layer::Int
    textures::Vector{Ptr{SDL2.SDL_Texture}}
    texturesBounds::Vector{Math._Vector4{Float64}}
    spriteHashes::Vector{UInt64}
    needsRebatch::Bool
    debugOffset::Math._Vector2{Float64}
    
    function BatchedLayer(layer::Int)
        this = new()
        this.layer = layer
        this.textures = Ptr{SDL2.SDL_Texture}[]
        this.texturesBounds = Math._Vector4{Float64}[]
        this.spriteHashes = UInt64[]
        this.needsRebatch = true
        this.debugOffset = Math._Vector2{Float64}(0.0, 0.0)
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
    Sp = JulGame.Component.SpriteModule.InternalSprite
    layer_sprites = Dict{Int, Vector{Sp}}()
    JulGame.MAIN === nothing && return layer_sprites
    ml = JulGame.current_main()
    sc = getfield(ml, :scene)::JulGame.SceneModule.Scene
    ents = getfield(sc, :entities)::Vector{JulGame.EntityModule.Entity}
    for entity in ents
        spr = getfield(entity, :sprite)
        spr isa Sp || continue
        sp = spr::Sp
        getfield(sp, :isStatic) || continue
        ly = getfield(sp, :layer)::Int
        if !haskey(layer_sprites, ly)
            layer_sprites[ly] = Sp[]
        end
        push!(layer_sprites[ly], sp)
    end
    return layer_sprites
end

"""
    calculate_bounding_box(sprites::Vector)

Calculate the minimal bounding box that contains all sprites.
Returns (min_x, min_y, max_x, max_y) in world coordinates.
"""
function calculate_bounding_box(sprites::AbstractVector{JulGame.Component.SpriteModule.InternalSprite})::NTuple{4, Float64}
    if isempty(sprites)
        return (0.0, 0.0, 0.0, 0.0)::NTuple{4, Float64}
    end
    
    min_x::Float64 = Inf
    min_y::Float64 = Inf
    max_x::Float64 = -Inf
    max_y::Float64 = -Inf
    
    SCALE_UNITS = JulGame.scale_units()
    
    for sprite in sprites
        entity = getfield(sprite, :parent)::JulGame.EntityModule.Entity
        tr = getfield(entity, :transform)::JulGame.TransformModule.Transform
        pos = getfield(tr, :position)
        scale = getfield(tr, :scale)
        
        cr = getfield(sprite, :crop)
        cropWidth::Float64 = if cr isa Math.Vector4
            cv = cr::Math._Vector4{Int32}
            if cv == _BATCH_V4_ZERO_I32
                Float64(getfield(getfield(sprite, :size), :x))
            else
                Float64(getfield(cv, :z))
            end
        else
            Float64(getfield(getfield(sprite, :size), :x))
        end
        cropHeight::Float64 = if cr isa Math.Vector4
            cv = cr::Math._Vector4{Int32}
            if cv == _BATCH_V4_ZERO_I32
                Float64(getfield(getfield(sprite, :size), :y))
            else
                Float64(getfield(cv, :t))
            end
        else
            Float64(getfield(getfield(sprite, :size), :y))
        end
        
        if getfield(sprite, :pixelsPerUnit) == 0
            sprite_width = cropWidth * Float64(getfield(scale, :x)) / 64.0
            sprite_height = cropHeight * Float64(getfield(scale, :y)) / 64.0
        else
            ppu = getfield(sprite, :pixelsPerUnit)
            ppu_eff::Float64 = ppu > 0 ? Float64(ppu) : Float64(_STATIC_BATCH_DEFAULT_PPU)
            sprite_width = cropWidth * Float64(getfield(scale, :x)) / ppu_eff
            sprite_height = cropHeight * Float64(getfield(scale, :y)) / ppu_eff
        end
        
        base_x = Float64(getfield(pos, :x)) + Float64(getfield(getfield(sprite, :offset), :x))
        base_y = Float64(getfield(pos, :y)) + Float64(getfield(getfield(sprite, :offset), :y))
        
        anch = getfield(sprite, :anchor)::Symbol
        if anch === :center
            x1 = base_x - sprite_width / 2
            y1 = base_y - sprite_height / 2
        elseif anch === :top
            x1 = base_x - sprite_width / 2
            y1 = base_y
        elseif anch === :bottom
            x1 = base_x - sprite_width / 2
            y1 = base_y - sprite_height
        elseif anch === :left
            x1 = base_x
            y1 = base_y - sprite_height / 2
        elseif anch === :right
            x1 = base_x - sprite_width
            y1 = base_y - sprite_height / 2
        elseif anch === :topleft
            x1 = base_x
            y1 = base_y
        elseif anch === :topright
            x1 = base_x - sprite_width
            y1 = base_y
        elseif anch === :bottomleft
            x1 = base_x
            y1 = base_y - sprite_height
        elseif anch === :bottomright
            x1 = base_x - sprite_width
            y1 = base_y - sprite_height
        else
            x1 = base_x - sprite_width / 2
            y1 = base_y - sprite_height / 2
        end
        
        x2 = x1 + sprite_width
        y2 = y1 + sprite_height
        
        min_x = Base.min(min_x, x1)
        min_y = Base.min(min_y, y1)
        max_x = Base.max(max_x, x2)
        max_y = Base.max(max_y, y2)
    end
    
    return (min_x, min_y, max_x, max_y)::NTuple{4, Float64}
end

"""
    create_batched_texture_for_sprites(sprites::Vector, bounds::NTuple{4, Float64})

Create a single texture containing all sprites.
Returns the texture pointer or C_NULL on failure.
"""
function create_batched_texture_for_sprites(sprites::AbstractVector{JulGame.Component.SpriteModule.InternalSprite}, bounds::NTuple{4, Float64})
    min_x, min_y, max_x, max_y = bounds
    
    # Calculate texture dimensions in pixels
    SCALE_UNITS = JulGame.scale_units()
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
    su_tex::Float64 = Float64(SCALE_UNITS)
    for sprite in sprites
        render_sprite_to_texture(sprite, min_x, min_y, su_tex)
    end
    
    # Reset render target to screen
    SDL2.SDL_SetRenderTarget(JulGame.Renderer, C_NULL)
    
    return texture
end

"""
    render_sprite_to_texture(sprite, offset_x, offset_y, scale_units)

Render a single sprite to the current render target (batched texture).
"""
function render_sprite_to_texture(sprite::JulGame.Component.SpriteModule.InternalSprite, offset_x::Float64, offset_y::Float64, scale_units::Float64)::Nothing
    if getfield(sprite, :texture) == C_NULL && getfield(sprite, :image) != C_NULL
        setfield!(sprite, :texture, SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, getfield(sprite, :image)))
        JulGame.Component.set_color(sprite)
    end
    
    if getfield(sprite, :texture) == C_NULL
        return nothing
    end
    
    col = getfield(sprite, :color)::NTuple{4, Int}
    SDL2.SDL_SetTextureColorMod(
        getfield(sprite, :texture),
        UInt8(clamp(col[1], 0, 255)),
        UInt8(clamp(col[2], 0, 255)),
        UInt8(clamp(col[3], 0, 255))
    )
    SDL2.SDL_SetTextureAlphaMod(getfield(sprite, :texture), UInt8(clamp(col[4], 0, 255)))
    
    entity = getfield(sprite, :parent)
    tr = getfield(entity, :transform)::JulGame.TransformModule.Transform
    pos = getfield(tr, :position)
    scale = getfield(tr, :scale)
    
    cr = getfield(sprite, :crop)
    cropWidth::Float64 = if cr isa Math.Vector4
        cv = cr::Math._Vector4{Int32}
        (cv == _BATCH_V4_ZERO_I32) ? Float64(getfield(getfield(sprite, :size), :x)) : Float64(getfield(cv, :z))
    else
        Float64(getfield(getfield(sprite, :size), :x))
    end
    cropHeight::Float64 = if cr isa Math.Vector4
        cv = cr::Math._Vector4{Int32}
        (cv == _BATCH_V4_ZERO_I32) ? Float64(getfield(getfield(sprite, :size), :y)) : Float64(getfield(cv, :t))
    else
        Float64(getfield(getfield(sprite, :size), :y))
    end
    
    scx = Float64(getfield(scale, :x))
    scy = Float64(getfield(scale, :y))
    if getfield(sprite, :pixelsPerUnit) == 0
        scaledWidth = cropWidth * scx * scale_units / 64.0
        scaledHeight = cropHeight * scy * scale_units / 64.0
    else
        ppu = getfield(sprite, :pixelsPerUnit)
        ppu_eff::Float64 = ppu > 0 ? Float64(ppu) : Float64(_STATIC_BATCH_DEFAULT_PPU)
        scaleFactor = scale_units / ppu_eff
        scaledWidth = cropWidth * scaleFactor * scx
        scaledHeight = cropHeight * scaleFactor * scy
    end
    
    off = getfield(sprite, :offset)::Math._Vector2{Float64}
    px = Float64(getfield(pos, :x))
    py = Float64(getfield(pos, :y))
    ox = Float64(getfield(off, :x))
    oy = Float64(getfield(off, :y))
    adjustedX = (px + ox) * scale_units - offset_x * scale_units
    adjustedY = (py + oy) * scale_units - offset_y * scale_units
    
    centeredX::Float64 = adjustedX
    centeredY::Float64 = adjustedY
    su_scx = scale_units * scx
    su_scy = scale_units * scy
    
    anch = getfield(sprite, :anchor)::Symbol
    if anch === :center
        centeredX -= (scaledWidth - su_scx) / 2
        centeredY -= (scaledHeight - su_scy) / 2
    elseif anch === :top
        centeredX -= (scaledWidth - su_scx) / 2
    elseif anch === :bottom
        centeredX -= (scaledWidth - su_scx) / 2
        centeredY -= (scaledHeight - su_scy)
    elseif anch === :left
        centeredY -= (scaledHeight - su_scy) / 2
    elseif anch === :right
        centeredX -= (scaledWidth - su_scx)
        centeredY -= (scaledHeight - su_scy) / 2
    elseif anch === :topleft
    elseif anch === :topright
        centeredX -= (scaledWidth - su_scx)
    elseif anch === :bottomleft
        centeredY -= (scaledHeight - su_scy)
    elseif anch === :bottomright
        centeredX -= (scaledWidth - su_scx)
        centeredY -= (scaledHeight - su_scy)
    end
    
    srcRect = if cr isa Math.Vector4
        cvr = cr::Math._Vector4{Int32}
        if cvr == _BATCH_V4_ZERO_I32
            C_NULL
        else
            Ref(SDL2.SDL_Rect(
                Math.TypeConversions.safe_int32_convert(Float64(getfield(cvr, :x))),
                Math.TypeConversions.safe_int32_convert(Float64(getfield(cvr, :y))),
                Math.TypeConversions.safe_int32_convert(Float64(getfield(cvr, :z))),
                Math.TypeConversions.safe_int32_convert(Float64(getfield(cvr, :t))),
            ))
        end
    else
        C_NULL
    end
    
    dstRect = Ref(SDL2.SDL_Rect(
        _batch_safe_round_i32(centeredX),
        _batch_safe_round_i32(centeredY),
        _batch_safe_round_i32(scaledWidth),
        _batch_safe_round_i32(scaledHeight),
    ))
    
    ctr = getfield(sprite, :center)::Math._Vector2{Float64}
    wrect = getfield(dstRect[], :w)
    hrect = getfield(dstRect[], :h)
    cx_f = Float64(wrect) * (Float64(getfield(ctr, :x)) % 1.0)
    cy_f = Float64(hrect) * (Float64(getfield(ctr, :y)) % 1.0)
    rotationCenter = Ref(SDL2.SDL_Point(
        _batch_safe_round_i32(cx_f),
        _batch_safe_round_i32(cy_f),
    ))
    
    SDL2.SDL_RenderCopyEx(
        JulGame.Renderer,
        getfield(sprite, :texture),
        srcRect,
        dstRect,
        getfield(sprite, :rotation),
        rotationCenter,
        getfield(sprite, :isFlipped) ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE
    )
    return nothing
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
        su = JulGame.scale_units()
        texture_width = ceil(Int32, (max_x - min_x) * su)
        texture_height = ceil(Int32, (max_y - min_y) * su)
        
        if texture_width > MAX_TEXTURE_SIZE || texture_height > MAX_TEXTURE_SIZE
            @debug "Layer $(layer) exceeds max texture size, will need chunking in future"
            # TODO: Implement chunking for very large layers
            # For now, clamp to max size (sprites outside will be cut off)
        end
        
        # Create batched texture
        texture = create_batched_texture_for_sprites(sprites, bounds)
        
        if texture != C_NULL
            push!(batched_layer.textures, texture)
            push!(batched_layer.texturesBounds, Math._Vector4{Float64}(min_x, min_y, max_x - min_x, max_y - min_y))
            
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
function render_batched_layer(batched_layer::BatchedLayer, camera::Union{Nothing, JulGame.CameraModule.Camera})
    if isempty(batched_layer.textures)
        return
    end
    
    S = JulGame.CameraModule.pixels_per_world_unit(camera)
    
    if camera === nothing
        cameraDiff = JulGame.Math._Vector2{Float64}(0.0, 0.0)
        cameraSize = JulGame.Math._Vector2{Int32}(0, 0)
        cameraPosition = JulGame.Math._Vector3{Float64}(0.0, 0.0, 0.0)
    else
        cam = camera::JulGame.CameraModule.Camera
        pos = getfield(cam, :position)::JulGame.Math._Vector3{Float64}
        off = getfield(cam, :offset)::JulGame.Math._Vector2{Float64}
        cameraDiff = JulGame.Math._Vector2{Float64}((pos.x + off.x) * S, (pos.y + off.y) * S)
        cameraSize = getfield(cam, :size)::JulGame.Math._Vector2{Int32}
        cameraPosition = pos
    end
    
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
        bl = scene.batchedLayers[layer]::BatchedLayer
        bl.needsRebatch = true
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
    
    for (layer, bl_u) in scene.batchedLayers
        batched_layer = bl_u::BatchedLayer
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
    for (layer, bl_u) in scene.batchedLayers
        batched_layer = bl_u::BatchedLayer
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
                    bx = bounds[1]
                    by = bounds[2]
                    bw = bounds[3] - bounds[1]
                    bh = bounds[4] - bounds[2]
                    push!(batched_layer.texturesBounds, Math._Vector4{Float64}(bx, by, bw, bh))
                    
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

