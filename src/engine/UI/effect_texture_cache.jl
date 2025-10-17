module EffectTextureCacheModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    export EffectTextureCache, get_or_create_texture!, mark_dynamic!, clear_scene_cache!, destroy_cache!, compute_key, estimate_bytes

    const MAX_CACHE_BYTES_DEFAULT = 200 * 1024 * 1024

    mutable struct CacheEntry
        key::UInt64
        texture::Ptr{SDL2.SDL_Texture}
        width::Int
        height::Int
        bytes::Int
        lastUsed::UInt64
        isDynamic::Bool
    end

    mutable struct EffectTextureCache
        entries::Dict{UInt64, CacheEntry}
        lru::Vector{UInt64}
        maxBytes::Int
        usedBytes::Int
        dynamicPool::Vector{Ptr{SDL2.SDL_Texture}}
        function EffectTextureCache(; maxBytes::Int=MAX_CACHE_BYTES_DEFAULT)
            new(Dict{UInt64, CacheEntry}(), UInt64[], maxBytes, 0, Ptr{SDL2.SDL_Texture}[])
        end
    end

    function touch!(cache::EffectTextureCache, key::UInt64)
        ts = UInt64(time_ns())
        if haskey(cache.entries, key)
            cache.entries[key].lastUsed = ts
        end
    end

    function evict_if_needed!(cache::EffectTextureCache)
        while cache.usedBytes > cache.maxBytes && !isempty(cache.entries)
            # find least recently used
            oldest_key = first(keys(cache.entries))
            oldest_ts = cache.entries[oldest_key].lastUsed
            for (k, v) in cache.entries
                if v.lastUsed < oldest_ts && !v.isDynamic
                    oldest_key = k
                    oldest_ts = v.lastUsed
                end
            end
            entry = cache.entries[oldest_key]
            if entry.texture != C_NULL
                SDL2.SDL_DestroyTexture(entry.texture)
            end
            cache.usedBytes -= entry.bytes
            delete!(cache.entries, oldest_key)
        end
    end

    function compute_key(hash_inputs::Vector{UInt64})::UInt64
        h::UInt64 = 0x9e3779b97f4a7c15
        for v in hash_inputs
            h ⊻= v + 0x9e3779b97f4a7c15 + (h << 6) + (h >> 2)
        end
        return h
    end

    function estimate_bytes(w, h)
        return Math.TypeConversions.safe_int32_convert(w*h*4)
    end

    function get_or_create_texture!(cache::EffectTextureCache, key::UInt64, create_fn::Function, isDynamic::Bool)
        if haskey(cache.entries, key)
            touch!(cache, key)
            return cache.entries[key].texture
        end
        
        # Evict BEFORE creating the new texture to make room
        bytes_needed = 1024 * 1024  # Estimate 1MB per texture initially
        while cache.usedBytes + bytes_needed > cache.maxBytes && !isempty(cache.entries)
            # find least recently used non-dynamic entry
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
            entry = cache.entries[oldest_key]
            if entry.texture != C_NULL
                SDL2.SDL_DestroyTexture(entry.texture)
            end
            cache.usedBytes -= entry.bytes
            delete!(cache.entries, oldest_key)
        end
        
        tex, w, h = create_fn()
        if tex == C_NULL
            return C_NULL
        end
        bytes = estimate_bytes(w,h)
        cache.usedBytes += bytes
        cache.entries[key] = CacheEntry(key, tex, w, h, bytes, UInt64(time_ns()), isDynamic)
        return tex
    end

    function mark_dynamic!(cache::EffectTextureCache, key::UInt64, isDynamic::Bool)
        if haskey(cache.entries, key)
            cache.entries[key].isDynamic = isDynamic
        end
    end

    function clear_scene_cache!(cache::EffectTextureCache)
        # aggressively clear non-dynamic cached textures on scene switch
        for (k, v) in collect(cache.entries)
            if !v.isDynamic
                if v.texture != C_NULL
                    SDL2.SDL_DestroyTexture(v.texture)
                end
                delete!(cache.entries, k)
            end
        end
        cache.usedBytes = 0
    end

    function destroy_cache!(cache::EffectTextureCache)
        for v in values(cache.entries)
            if v.texture != C_NULL
                SDL2.SDL_DestroyTexture(v.texture)
            end
        end
        empty!(cache.entries)
        empty!(cache.lru)
        cache.usedBytes = 0
    end
end


