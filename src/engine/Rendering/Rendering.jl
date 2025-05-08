module Rendering
using ..JulGame

# import ..JulGame: 
#     function_to_modify,


    function queue_render_function(render_function::Function; isWorldEntity::Bool = true, layer::Int = 0)
        push!(JulGame.RENDER_FUNCTIONS, (function_to_call = render_function, isWorldEntity = isWorldEntity, layer = layer))
    end
end
