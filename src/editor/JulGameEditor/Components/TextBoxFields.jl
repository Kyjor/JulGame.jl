function show_textbox_fields(selectedTextBox, textBoxField)
    fieldName = getFieldName(textBoxField)
    Value = getproperty(selectedTextBox, textBoxField)

    if fieldName == "text" || fieldName == "name" 
        buf = "$(Value)"*"\0"^(64)
        CImGui.InputText("$(textBoxField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setproperty!(selectedTextBox, textBoxField, currentTextInTextBox)
        
        if currentTextInTextBox != Value
            selectedTextBox.text = selectedTextBox.text        
        end
    elseif fieldName == "color"
        # Instead of using a function from another module, use CImGui directly here
        colorCfloat = Cfloat[Value[1]/255, Value[2]/255, Value[3]/255, Value[4]/255]
        
        # Configure color editor options
        misc_flags = CImGui.ImGuiColorEditFlags_AlphaPreview | 
                    CImGui.ImGuiColorEditFlags_AlphaBar | 
                    CImGui.ImGuiColorEditFlags_DisplayRGB
        
        if CImGui.ColorEdit4("TextBoxColor", colorCfloat, misc_flags)
            newColor = (Int(abs(round(colorCfloat[1] * 255))), 
                        Int(abs(round(colorCfloat[2] * 255))), 
                        Int(abs(round(colorCfloat[3] * 255))), 
                        Int(abs(round(colorCfloat[4] * 255))))
            
            selectedTextBox.color = newColor
            selectedTextBox.text = selectedTextBox.text  # Trigger update
        end
    elseif fieldName == "position" || fieldName == "anchorOffset"
        x = Cint(Value.x)
        y = Cint(Value.y)
        @c CImGui.InputInt("$(textBoxField) x", &x, 1)
        @c CImGui.InputInt("$(textBoxField) y", &y, 1)
        
        if x != Value.x || y != Value.y
            #selectedTextBox.setVector2Value(textBoxField, convert(Float64, x), convert(Float64, y))
            setproperty!(selectedTextBox, textBoxField, Vector2(x, y))
            selectedTextBox.text = selectedTextBox.text
        end
    elseif fieldName == "autoSizeText" || fieldName == "isCenteredX" || fieldName == "isCenteredY" || fieldName == "isWorldEntity" || fieldName == "isActive"
        @c CImGui.Checkbox("$(textBoxField)", &Value)

        if Value != getproperty(selectedTextBox, textBoxField)
            setproperty!(selectedTextBox, textBoxField, Value)
            selectedTextBox.text = selectedTextBox.text
        end
    elseif fieldName == "fontSize"
        newSize = Cint(Value)
        @c CImGui.InputInt("$(textBoxField)", &newSize, 1)
        
        if newSize != Value
            JulGame.update_font_size(selectedTextBox, round(Int, newSize))
        end
    elseif fieldName == "anchor"
        currentState = "$(selectedTextBox.anchor.current_state)"
        if @c CImGui.BeginCombo("$(textBoxField)", currentState)
            for option in ["none", "center", "topLeft", "topRight", "bottomLeft", "bottomRight", "centerLeft", "centerRight", "centerTop", "centerBottom"]
                isSelected = currentState == option
                if @c CImGui.Selectable(option, isSelected)
                    #println("selected $option")
                    selectedTextBox.anchor.current_state = Symbol(option)
                end
                if isSelected
                    CImGui.SetItemDefaultFocus()
                end
            end
            CImGui.EndCombo()
        end
    end
end

function getFieldName(field)
    return "$(field)"
end