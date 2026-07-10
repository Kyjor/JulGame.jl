function serialize_effects(effects::Vector{Any})::String
    if isempty(effects)
        return "[]"
    end
    parts = String[]
    for eff in effects
        T = typeof(eff)
        fnames = fieldnames(T)
        vals = String[]
        for f in fnames
            v = getfield(eff, f)
            if v isa Ptr
                push!(vals, string(f, "=Ptr"))
            else
                push!(vals, string(f, "=", v))
            end
        end
        push!(parts, string(nameof(T), "(", join(vals, ","), ")"))
    end
    return "[" * join(parts, ";") * "]"
end

function generate_effect_cache_key(imagePath::String, size::Math.Vector2, effects::Vector{Any})::String
    content = string(
        imagePath, "|",
        size.x, "x", size.y, "|",
        serialize_effects(effects)
    )
    return string(hash(content))
end

function generate_effect_cache_key(this::InternalSprite)::String
    return generate_effect_cache_key(this.imagePath, this.size, this.effects)
end

#  effects API
function Component.apply_effects!(this::InternalSprite, effects::Vector)
    this.effects = Any[effect for effect in effects]  # Convert to Vector{Any}
    
    # Generate cache key and check if we need to recompute
    newKey = generate_effect_cache_key(this)
    if this.effectCacheKey == newKey && this.effectTexture != C_NULL
        # Already have this effect cached on this sprite
        @debug "Sprite.apply_effects!: cache key unchanged; skipping recompute" path=this.imagePath
        return this
    end
    
    this.effectCacheKey = newKey
    this.needsEffectUpdate = true
    update_effects(this)
    return this
end

function apply_style!(this::InternalSprite, style)
    return apply_effects!(this, style.effects)
end

function update_effects(this::InternalSprite)
    if isempty(this.effects) || !this.needsEffectUpdate
        return
    end
    
    # Check shared cache first
    if haskey(SPRITE_EFFECT_CACHE, this.effectCacheKey)
        cached = SPRITE_EFFECT_CACHE[this.effectCacheKey]
        this.effectTexture = cached[1]
        this.effectSize = cached[2]
        this.needsEffectUpdate = false
        @debug "Sprite using cached effect texture" path=this.imagePath key=this.effectCacheKey
        return
    end
    
    # Create target for effects
    target = JG.EffectsModule.SpriteTarget(this)
    
    # Apply effects
    try
        result = JG.EffectRendererModule.apply_effects!(target, this.effects)
        if result isa JG.EffectsModule.SpriteTarget
            # Effect texture should be updated by the renderer
            # Query the effect texture size and store it
            if this.effectTexture != C_NULL
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                SDL2.SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                this.effectSize = Math.Vector2(w[], h[])
                
                # Cache the result for other sprites with same visuals
                SPRITE_EFFECT_CACHE[this.effectCacheKey] = (this.effectTexture, this.effectSize)
                @debug "Cached sprite effect texture" path=this.imagePath key=this.effectCacheKey
            end
            this.needsEffectUpdate = false
        end
    catch e
        @error("Failed to apply effects to sprite: $e")
    end
end

function clear_sprite_effects_cache()
    for (key, cached) in SPRITE_EFFECT_CACHE
        if cached[1] != C_NULL
            SDL2.SDL_DestroyTexture(cached[1])
        end
    end
    empty!(SPRITE_EFFECT_CACHE)
end

function get_effect_cache_snapshot()
    snapshot = NamedTuple[]
    for (key, cached) in SPRITE_EFFECT_CACHE
        texture = cached[1]
        size = cached[2]
        width = Int(round(size.x))
        height = Int(round(size.y))
        if (width <= 0 || height <= 0) && texture != C_NULL
            w = Ref{Cint}(0)
            h = Ref{Cint}(0)
            fmt = Ref{UInt32}(0)
            access = Ref{Cint}(0)
            if SDL2.SDL_QueryTexture(texture, fmt, access, w, h) == 0
                width = Int(w[])
                height = Int(h[])
            end
        end
        push!(snapshot, (
            key = key,
            texture = texture,
            width = width,
            height = height,
            approxBytes = width * height * 4,
        ))
    end
    return snapshot
end

function clear_texture_cache()
    for (key, tex) in TEXTURE_CACHE
        if tex != C_NULL
            SDL2.SDL_DestroyTexture(tex)
        end
    end
    empty!(TEXTURE_CACHE)
end

"""
    release_sprite_texture_for_mutation!(sprite::InternalSprite)

Drop this sprite's texture before pixel-mutating effects (e.g. clock-hand sweep).
The shared `TEXTURE_CACHE` entry is left untouched — other sprites with the same
`imagePath` (which may never mutate) keep rendering from it. Only textures that
are not referenced by the cache (i.e. private, from a previous mutation) are
destroyed. The sprite then gets its own private texture on the next update.
"""
function release_sprite_texture_for_mutation!(sprite::InternalSprite)
    tex = sprite.texture
    tex == C_NULL && return
    if !(tex in values(TEXTURE_CACHE))
        SDL2.SDL_DestroyTexture(tex)
    end
    sprite.texture = C_NULL
end
