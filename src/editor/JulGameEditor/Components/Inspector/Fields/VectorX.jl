function show_field(structure::EditableStructure, field::Symbol, value::Union{Math._Vector2{Float64}, Math._Vector2{Int32}})
    slider_flags = CImGui.ImGuiSliderFlags_InlineLabel
    is_float = isa(value, Math._Vector2{Float64})
    max_value = is_float ? typemax(Cfloat) : typemax(Cint)
    val = is_float ? Cfloat[value.x, value.y] : Cint[value.x, value.y]
    
    # Custom multi-component layout
    CImGui.igPushMultiItemsWidths(2, CImGui.CalcItemWidth())
    
    # X component
    if is_float
        @c CImGui.DragFloat("X", pointer(val, 1), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("X", pointer(val, 1), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    
    # Y component
    if is_float
        @c CImGui.DragFloat("Y", pointer(val, 2), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("Y", pointer(val, 2), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    CImGui.Text(string(field))

    if val[1] != value.x || val[2] != value.y
        setfield!(structure, field, is_float ? Math._Vector2{Float64}(val[1], val[2]) : Math._Vector2{Int32}(val[1], val[2]))
    end

    return val[1] != value.x || val[2] != value.y
end

function show_field(structure::EditableStructure, field::Symbol, value::Union{Math._Vector3{Float64}, Math._Vector3{Int32}})
    slider_flags = CImGui.ImGuiSliderFlags_InlineLabel
    is_float = isa(value, Math._Vector3{Float64})
    max_value = is_float ? typemax(Cfloat) : typemax(Cint)
    val = is_float ? Cfloat[value.x, value.y, value.z] : Cint[value.x, value.y, value.z]
    
    # Custom multi-component layout
    CImGui.igPushMultiItemsWidths(3, CImGui.CalcItemWidth())
    
    # X component
    if is_float
        @c CImGui.DragFloat("X", pointer(val, 1), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("X", pointer(val, 1), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    
    # Y component
    if is_float
        @c CImGui.DragFloat("Y", pointer(val, 2), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("Y", pointer(val, 2), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    
    # Z component
    if is_float
        @c CImGui.DragFloat("Z", pointer(val, 3), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("Z", pointer(val, 3), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    CImGui.Text(string(field))

    if val[1] != value.x || val[2] != value.y || val[3] != value.z
        setfield!(structure, field, is_float ? Math._Vector3{Float64}(val[1], val[2], val[3]) : Math._Vector3{Int32}(val[1], val[2], val[3]))
    end

    return val[1] != value.x || val[2] != value.y || val[3] != value.z
end

function show_field(structure::EditableStructure, field::Symbol, value::Union{Math._Vector4{Float64}, Math._Vector4{Int32}})
    slider_flags = CImGui.ImGuiSliderFlags_InlineLabel
    is_float = isa(value, Math._Vector4{Float64})
    max_value = is_float ? typemax(Cfloat) : typemax(Cint)
    val = is_float ? Cfloat[value.x, value.y, value.z, value.t] : Cint[value.x, value.y, value.z, value.t]
    
    # Custom multi-component layout
    CImGui.igPushMultiItemsWidths(4, CImGui.CalcItemWidth())
    
    # X component
    if is_float
        @c CImGui.DragFloat("X", pointer(val, 1), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("X", pointer(val, 1), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    
    # Y component
    if is_float
        @c CImGui.DragFloat("Y", pointer(val, 2), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("Y", pointer(val, 2), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    
    # Z component
    if is_float
        @c CImGui.DragFloat("Z", pointer(val, 3), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("Z", pointer(val, 3), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    
    # T component
    if is_float
        @c CImGui.DragFloat("T", pointer(val, 4), 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt("T", pointer(val, 4), 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()
    CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
    CImGui.Text(string(field))

    if val[1] != value.x || val[2] != value.y || val[3] != value.z || val[4] != value.t
        setfield!(structure, field, is_float ? Math._Vector4{Float64}(val[1], val[2], val[3], val[4]) : Math._Vector4{Int32}(val[1], val[2], val[3], val[4]))
    end

    return val[1] != value.x || val[2] != value.y || val[3] != value.z || val[4] != value.t
end