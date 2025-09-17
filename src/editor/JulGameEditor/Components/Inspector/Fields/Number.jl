function show_field(structure::EditableStructure, field::Symbol, value::Union{Int32, Int64})
    show_field_label(field)
    @c CImGui.InputInt("##$(string(field))", &value, 1)

    if value != value
        setfield!(structure, field, value)
    end
    
    return value != value
end