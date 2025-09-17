function show_field(structure::EditableStructure, field::Symbol, value::Union{Math._Vector2{Float64}, Math._Vector2{Int32}})
    
    val = isa(value, Math._Vector2{Float64}) ? Cfloat[value.x, value.y] : Cint[value.x, value.y]
    show_field_label(field)
    @c CImGui.InputFloat2("##$(string(field))", val)

    if val[1] != value.x || val[2] != value.y
        setfield!(structure, field, isa(value, Math._Vector2{Float64}) ? Math._Vector2{Float64}(val[1], val[2]) : Math._Vector2{Int32}(val[1], val[2]))
    end
    
    return val[1] != value.x || val[2] != value.y
end

function show_field(structure::EditableStructure, field::Symbol, value::Union{Math._Vector3{Float64}, Math._Vector3{Int32}})
    slider_flags = CImGui.ImGuiSliderFlags_None
    is_float = isa(value, Math._Vector3{Float64})
    max_value = is_float ? typemax(Cfloat) : typemax(Cint)
    val = is_float ? Cfloat[value.x, value.y, value.z] : Cint[value.x, value.y, value.z]
    show_field_label(field)
    CImGui.PushItemWidth(-1)  # fill remaining width
    if is_float
        @c CImGui.DragFloat3("##$(string(field))", val, 0.1, -max_value, max_value, "%.3f", slider_flags)
    else
        @c CImGui.DragInt3("##$(string(field))", val, 1, -max_value, max_value, "%d", slider_flags)
    end
    CImGui.PopItemWidth()

    if val[1] != value.x || val[2] != value.y || val[3] != value.z
        setfield!(structure, field, is_float ? Math._Vector3{Float64}(val[1], val[2], val[3]) : Math._Vector3{Int32}(val[1], val[2], val[3]))
    end

    return val[1] != value.x || val[2] != value.y || val[3] != value.z
end