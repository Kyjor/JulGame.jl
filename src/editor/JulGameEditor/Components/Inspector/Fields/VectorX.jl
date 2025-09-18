function show_field(structure::EditableStructure, field::Symbol, value::Union{Math._Vector2{Float64}, Math._Vector2{Int32}, Math._Vector3{Float64}, Math._Vector3{Int32}, Math._Vector4{Float64}, Math._Vector4{Int32}})
    slider_flags = CImGui.ImGuiSliderFlags_None # TODO: CImGui.ImGuiSliderFlags_InlineLabel
    is_float = isa(value, Math._Vector2{Float64}) || isa(value, Math._Vector3{Float64}) || isa(value, Math._Vector4{Float64})
    max_value = is_float ? typemax(Cfloat) : typemax(Cint)
    array_type = is_float ? Cfloat : Cint
    fields = fieldnames(typeof(value))
    val = array_type[getfield(value, fname) for fname in fields]
    
    # Custom multi-component layout
    available_width = CImGui.CalcItemWidth()
    num_components = length(fields)
    spacing = unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x)
    total_spacing = spacing * (num_components - 1)  # N-1 spaces between N components
    adjusted_width = available_width - total_spacing

    CImGui.igPushMultiItemsWidths(num_components, adjusted_width * 1.3)
    
    show_field_label(field)
    for i in eachindex(fields)
        if is_float
            @c CImGui.DragFloat("$(string(fields[i]))##$(field)_$(string(typeof(structure)))", pointer(val, i), 0.1, -max_value, max_value, "%.3f", slider_flags)
        else
            @c CImGui.DragInt("$(string(fields[i]))##$(field)_$(string(typeof(structure)))", pointer(val, i), 1, -max_value, max_value, "%d", slider_flags)
        end
        CImGui.PopItemWidth()
        if i < length(fields)
            CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
        end
    end
   
    changed = false
    if any(val[i] != getfield(value, fname) for (i, fname) in enumerate(fields))
        new_value = typeof(value)(val...)  # Construct new vector with updated values
        setfield!(structure, field, new_value)
        changed = true
    end

    return changed
end