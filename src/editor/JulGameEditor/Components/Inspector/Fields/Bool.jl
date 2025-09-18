function show_field(structure::EditableStructure, field::Symbol, value::Bool)
    val = value
    show_field_label(field)
    @c CImGui.Checkbox("##$(string(field))_$(string(typeof(structure)))", &val)

    if val != value
        setfield!(structure, field, val)
    end
    
    return val != value
end