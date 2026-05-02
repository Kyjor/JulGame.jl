module Rendering
using ..JulGame

    function queue_render_function(render_function; isWorldEntity::Bool = true, layer::Int = 0)
        fn::Function = render_function isa Function ? render_function::Function : () -> Base.invokelatest(render_function)
        push!(JulGame.RENDER_FUNCTIONS, JulGame.RenderQueuedFunction(fn, isWorldEntity, layer))
    end
end
