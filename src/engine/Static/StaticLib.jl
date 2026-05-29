using StaticTools

include("wallocstring.jl")

function static_is_mouse_inside_element(mouse_x::Int32, mouse_y::Int32, element_x::Int32, element_y::Int32, element_width::Int32, element_height::Int32)::Bool
    if mouse_x < element_x
        return false
    elseif mouse_x > element_x + element_width
        return false
    elseif mouse_y < element_y
        return false
    elseif mouse_y > element_y + element_height
        return false
    end
    return true
end
