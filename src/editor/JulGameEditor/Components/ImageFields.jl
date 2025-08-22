function show_image_fields(selectedImage, imageField)
    fieldName = getImageFieldName(imageField)
    unusedFields = ["imageSprite", "imageTexture", "isInitialized"]
    
    if fieldName in unusedFields
        return
    end
    
    Value = getfield(selectedImage, imageField)

    if fieldName == "name" 
        buf = "$(Value)"*"\0"^(64)
        CImGui.InputText("$(imageField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(selectedImage, imageField, currentTextInTextBox)
        
    elseif fieldName == "alpha"
        x = Cint(Value)
        @c CImGui.SliderInt("$(imageField)", &x, 0, 255)
        setfield!(selectedImage, imageField, convert(Int32, round(x)))

    elseif fieldName == "position" || fieldName == "size"
        x = Cint(Value.x)
        y = Cint(Value.y)
        @c CImGui.InputInt("$(imageField) x", &x, 1)
        @c CImGui.InputInt("$(imageField) y", &y, 1)
        
        if x != Value.x || y != Value.y
            setfield!(selectedImage, imageField, Vector2(x, y))
        end
    elseif fieldName == "persistentBetweenScenes"
        @c CImGui.Checkbox("$(imageField)", &Value)

        if Value != getfield(selectedImage, imageField)
            setfield!(selectedImage, imageField, Value)
        end
    end
end

function getImageFieldName(field)
    return "$(field)"
end