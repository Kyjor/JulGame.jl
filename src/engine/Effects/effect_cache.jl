module EffectCacheModule
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    import ...JulGame
    const Math = JulGame.Math
    using ..EffectsModule

    export EffectCache, get_or_create_texture!, evict_if_needed!, estimate_bytes, compute_key
    export get_cache_stats, get_cache_entries_snapshot, get_global_cache_snapshot

    mutable struct CacheEntry
        key::UInt64
        texture::Ptr{SDL2.SDL_Texture}
        width::Int
        height::Int
        bytes::Int
        lastUsed::UInt64
        isDynamic::Bool
    end

    mutable struct EffectCache
        entries::Dict{UInt64, CacheEntry}
        maxBytes::Int
        usedBytes::Int
        function EffectCache(maxBytes::Int=100*1024*1024)  # 100MB default
            new(Dict{UInt64, CacheEntry}(), maxBytes, 0)
        end
    end

    const CACHE = Ref{EffectCache}(EffectCache())

    function estimate_bytes(width::Int, height::Int)::Int
        # Estimate bytes for RGBA32 texture
        return width * height * 4
    end

    function compute_key(parts::Vector{UInt64})::UInt64
        # Simple hash combination
        result = UInt64(0)
        for part in parts
            result = result ⊻ (part << 1) ⊻ (part >> 1)
        end
        return result
    end

    function make_key(target::EffectsModule.EffectTarget, effects::Vector{EffectsModule.Effect})::UInt64
        parts = UInt64[]
        
        # Add target-specific hash
        if target isa EffectsModule.SurfaceTarget
            push!(parts, hash("SurfaceTarget"))
            if target.surface != C_NULL
                arr = unsafe_wrap(Array, target.surface, 10; own=false)
                push!(parts, UInt64(arr[1].w))
                push!(parts, UInt64(arr[1].h))
            end
        elseif target isa EffectsModule.TextureTarget
            push!(parts, hash("TextureTarget"))
            push!(parts, UInt64(target.width))
            push!(parts, UInt64(target.height))
        elseif target isa EffectsModule.SpriteTarget
            push!(parts, hash("SpriteTarget"))
            push!(parts, hash(target.sprite.id))
        elseif target isa EffectsModule.RectangleTarget
            push!(parts, hash("RectangleTarget"))
            push!(parts, hash(target.rectangle.id))
        elseif target isa EffectsModule.LineTarget
            push!(parts, hash("LineTarget"))
            push!(parts, hash(target.line.id))
        elseif target isa EffectsModule.ImageTarget
            push!(parts, hash("ImageTarget"))
            push!(parts, hash(target.image.id))
        elseif target isa EffectsModule.Mesh3DTarget
            push!(parts, hash("Mesh3DTarget"))
            push!(parts, hash(target.mesh.id))
        end
        
        # Add effects hash
        for effect in effects
            push!(parts, hash(effect))
        end
        
        return compute_key(parts)
    end

    function touch!(cache::EffectCache, key::UInt64)
        if haskey(cache.entries, key)
            cache.entries[key].lastUsed = UInt64(time_ns())
        end
    end

    function evict_if_needed!(cache::EffectCache, bytes_needed::Int)
        while cache.usedBytes + bytes_needed > cache.maxBytes && !isempty(cache.entries)
            # Find least recently used non-dynamic entry
            oldest_key = nothing
            oldest_ts = typemax(UInt64)
            for (k, v) in cache.entries
                if !v.isDynamic && v.lastUsed < oldest_ts
                    oldest_key = k
                    oldest_ts = v.lastUsed
                end
            end
            if oldest_key === nothing
                break  # No more non-dynamic entries to evict
            end
            
            # Remove oldest entry
            entry = cache.entries[oldest_key]
            if entry.texture != C_NULL
                SDL2.SDL_DestroyTexture(entry.texture)
            end
            cache.usedBytes -= entry.bytes
            delete!(cache.entries, oldest_key)
        end
    end

    function get_or_create_texture!(cache::EffectCache, key::UInt64, create_fn::Function, isDynamic::Bool)
        if haskey(cache.entries, key)
            touch!(cache, key)
            return cache.entries[key].texture
        end
        
        # Evict BEFORE creating the new texture to make room
        bytes_needed = 1024 * 1024  # Estimate 1MB per texture initially
        evict_if_needed!(cache, bytes_needed)
        
        tex, w, h = create_fn()
        if tex == C_NULL
            return C_NULL
        end
        
        bytes = estimate_bytes(w, h)
        cache.usedBytes += bytes
        cache.entries[key] = CacheEntry(key, tex, w, h, bytes, UInt64(time_ns()), isDynamic)
        return tex
    end

    function clear_cache!(cache::EffectCache)
        for (key, entry) in cache.entries
            if entry.texture != C_NULL
                SDL2.SDL_DestroyTexture(entry.texture)
            end
        end
        empty!(cache.entries)
        cache.usedBytes = 0
    end

    function get_cache_stats(cache::EffectCache)
        return (
            entries = length(cache.entries),
            usedBytes = cache.usedBytes,
            maxBytes = cache.maxBytes,
            usagePercent = (cache.usedBytes / cache.maxBytes) * 100
        )
    end

    function get_cache_entries_snapshot(cache::EffectCache)
        snapshot = NamedTuple[]
        for (key, entry) in cache.entries
            push!(
                snapshot,
                (
                    key = key,
                    texture = entry.texture,
                    width = entry.width,
                    height = entry.height,
                    bytes = entry.bytes,
                    isDynamic = entry.isDynamic,
                    lastUsed = entry.lastUsed,
                ),
            )
        end
        return snapshot
    end

    function get_global_cache_snapshot()
        cache = CACHE[]
        return (
            stats = get_cache_stats(cache),
            entries = get_cache_entries_snapshot(cache),
        )
    end
end
