function show_field(structure::EditableStructure, field::Symbol, value::JulGame.Enum{Any})
        currentState = "$(value.current_state)"
        show_field_label(field)
        if @c CImGui.BeginCombo("##$(field)", currentState)
            for option in collect(keys(value.states))
                isSelected = currentState == option
                if @c CImGui.Selectable(option, isSelected)
                    println("selected $option")
                    setproperty!(value, :current_state, option)
                end
                if isSelected
                    CImGui.SetItemDefaultFocus()
                end
            end
            CImGui.EndCombo()
        end
end