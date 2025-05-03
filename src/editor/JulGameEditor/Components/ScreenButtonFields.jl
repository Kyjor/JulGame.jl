function show_screenbutton_fields(selectedScreenButton, screenButtonField)
    fieldName = getFieldName1(screenButtonField)
    unusedFields = ["alpha","clickEvents", "currentTexture", "buttonDownSprite", "buttonDownSpritePath", "buttonDownTexture", "buttonUpSprite", "buttonUpSpritePath", "buttonUpTexture", "fontPath", "isInitialized", "textTexture"]
    push!(unusedFields, "text")
    if fieldName in unusedFields
        return
    end
    Value = getfield(selectedScreenButton, screenButtonField)

    if fieldName == "text" || fieldName == "name" 
        buf = "$(Value)"*"\0"^(64)
        CImGui.InputText("$(screenButtonField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(selectedScreenButton, screenButtonField, currentTextInTextBox)
        
        if currentTextInTextBox != Value
            # JulGame.update_text(selectedScreenButton, selectedScreenButton.text)
        end

    elseif fieldName == "alpha"
        x = Cint(Value)
        @c CImGui.SliderInt("$(screenButtonField)", &x, 0, 255)
        setfield!(selectedScreenButton, screenButtonField, convert(Int32, round(x)))

        if x != Value
            # JulGame.update_text(selectedScreenButton, selectedScreenButton.text)
        end

    elseif fieldName == "color"
       # Instead of using a function from another module, use CImGui directly here
       colorCfloat = Cfloat[Value[1]/255, Value[2]/255, Value[3]/255, Value[4]/255]
        
       # Configure color editor options
       misc_flags = CImGui.ImGuiColorEditFlags_AlphaPreview | 
                   CImGui.ImGuiColorEditFlags_AlphaBar | 
                   CImGui.ImGuiColorEditFlags_DisplayRGB
       
       if CImGui.ColorEdit4("$(screenButtonField)", colorCfloat, misc_flags)
           newColor = (Int(abs(round(colorCfloat[1] * 255))), 
                       Int(abs(round(colorCfloat[2] * 255))), 
                       Int(abs(round(colorCfloat[3] * 255))), 
                       Int(abs(round(colorCfloat[4] * 255))))
           
           setfield!(selectedScreenButton, screenButtonField, Color(convert(Int32, round(r)), convert(Int32, round(g)), convert(Int32, round(b)), convert(Int32, round(a))))
        end
    elseif fieldName == "position" || fieldName == "size"
        x = Cint(Value.x)
        y = Cint(Value.y)
        @c CImGui.InputInt("$(screenButtonField) x", &x, 1)
        @c CImGui.InputInt("$(screenButtonField) y", &y, 1)
        
        if x != Value.x || y != Value.y
            #selectedScreenButton.setVector2Value(screenButtonField, convert(Float64, x), convert(Float64, y))
            setfield!(selectedScreenButton, screenButtonField, Vector2(x, y))
            # JulGame.update_text(selectedScreenButton, selectedScreenButton.text)
        end
    elseif fieldName == "autoSizeText" || fieldName == "isCentered"
        @c CImGui.Checkbox("$(screenButtonField)", &Value)

        if Value != getfield(selectedScreenButton, screenButtonField)
            setfield!(selectedScreenButton, screenButtonField, Value)
            # JulGame.update_text(selectedScreenButton, selectedScreenButton.text)
        end
    end
end

function getFieldName1(field)
    return "$(field)"
end