"""
Helper functions for debugging and configuring static sprite batching.
"""

"""
    set_batched_layer_offset(layer::Int, x::Float64, y::Float64)

Set a manual pixel offset for a batched layer for debugging alignment issues.
Positive X moves right, positive Y moves down.

# Example
```julia
# Shift layer 0 by 32 pixels right and 16 pixels down
JulGame.set_batched_layer_offset(0, 32.0, 16.0)

# Reset offset
JulGame.set_batched_layer_offset(0, 0.0, 0.0)
```
"""
function set_batched_layer_offset(layer::Int, x::Float64, y::Float64)
    if JulGame.MAIN === nothing || JulGame.MAIN.scene === nothing
        @warn "Cannot set batched layer offset: MAIN or scene not initialized"
        return
    end
    
    if !haskey(JulGame.MAIN.scene.batchedLayers, layer)
        @warn "Layer $(layer) is not batched or does not exist"
        return
    end
    
    batched_layer = JulGame.MAIN.scene.batchedLayers[layer]
    batched_layer.debugOffset = JulGame.Math.Vector2f(x, y)
    @debug "Set batched layer $(layer) offset to ($(x), $(y)) pixels"
end

"""
    get_batched_layer_offset(layer::Int)

Get the current debug offset for a batched layer.
"""
function get_batched_layer_offset(layer::Int)
    if JulGame.MAIN === nothing || JulGame.MAIN.scene === nothing
        @warn "Cannot get batched layer offset: MAIN or scene not initialized"
        return nothing
    end
    
    if !haskey(JulGame.MAIN.scene.batchedLayers, layer)
        @warn "Layer $(layer) is not batched or does not exist"
        return nothing
    end
    
    batched_layer = JulGame.MAIN.scene.batchedLayers[layer]
    return batched_layer.debugOffset
end

"""
    get_batched_layer_info(layer::Int)

Get diagnostic information about a batched layer.
"""
function get_batched_layer_info(layer::Int)
    if JulGame.MAIN === nothing || JulGame.MAIN.scene === nothing
        @warn "Cannot get batched layer info: MAIN or scene not initialized"
        return
    end
    
    if !haskey(JulGame.MAIN.scene.batchedLayers, layer)
        @warn "Layer $(layer) is not batched or does not exist"
        return
    end
    
    batched_layer = JulGame.MAIN.scene.batchedLayers[layer]
    
    println("=== Batched Layer $(layer) Info ===")
    println("Textures: $(length(batched_layer.textures))")
    println("Sprites: $(length(batched_layer.spriteHashes))")
    println("Needs rebatch: $(batched_layer.needsRebatch)")
    println("Debug offset: $(batched_layer.debugOffset)")
    
    for (i, bounds) in enumerate(batched_layer.texturesBounds)
        println("\nChunk $(i):")
        println("  World bounds: ($(bounds.x), $(bounds.y)) size $(bounds.z)x$(bounds.t)")
        println("  Texture size: $(ceil(Int, bounds.z * JulGame.SCALE_UNITS))x$(ceil(Int, bounds.t * JulGame.SCALE_UNITS)) pixels")
    end
end

"""
    list_batched_layers()

List all currently batched layers.
"""
function list_batched_layers()
    if JulGame.MAIN === nothing || JulGame.MAIN.scene === nothing
        @warn "Cannot list batched layers: MAIN or scene not initialized"
        return
    end
    
    if isempty(JulGame.MAIN.scene.batchedLayers)
        println("No batched layers in current scene")
        return
    end
    
    println("=== Batched Layers ===")
    for (layer, batched_layer) in sort(collect(JulGame.MAIN.scene.batchedLayers), by=x->x[1])
        println("Layer $(layer): $(length(batched_layer.spriteHashes)) sprites, offset $(batched_layer.debugOffset)")
    end
end

export set_batched_layer_offset, get_batched_layer_offset, get_batched_layer_info, list_batched_layers

