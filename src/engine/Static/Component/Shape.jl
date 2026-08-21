function static_draw_shape(shape::Ptr{Cvoid}, renderer::Ptr{Cvoid})
    if shape == C_NULL || renderer == C_NULL
        printf(c"renderer is null\n")
        return
    end

    this = Ptr{ShapeLayout}(shape)
    # parent_ptr::Ptr{Cvoid} = this.parent
    # if ptr_is_julia_nothing(parent_ptr)
    #     return
    # end
    # parent_entity = Ptr{EntityLayout}(parent_ptr)
    # transform_ptr::Ptr{Cvoid} = parent_entity.transform
    # if ptr_is_julia_nothing(transform_ptr)
    #     return
    # end
    # parent_transform = Ptr{TransformLayout}(transform_ptr)
    # printf(c"parent_transform \n")
    # printf(parent_transform.position.x)
    
    return
end
