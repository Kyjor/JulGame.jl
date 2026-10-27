module Rendering
using ..JulGame

    @inline function queue_render_function(render_function::F; isWorldEntity::Bool = true, layer::Int = 0) where {F}
        callback = render_function isa JulGame.HoverCallback ? render_function : JulGame.HoverCallback(render_function)
        push!(JulGame.RENDER_FUNCTIONS, JulGame.RenderFunction(callback, isWorldEntity, layer))
    end
end
