module Rendering
using ..JulGame

    function queue_render_function(render_function; isWorldEntity::Bool = true, layer::Int = 0)
        push!(JulGame.RENDER_FUNCTIONS, JulGame.RenderQueuedFunction(render_function, isWorldEntity, layer))
    end
end
