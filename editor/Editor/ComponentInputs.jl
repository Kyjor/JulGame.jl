using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame

const JulGameComponents = ["Transform", "Collider", "Rigidbody", "Animator", "Animation", "Entity", "SoundSource", "Sprite"]
"""
ShowComponentProperties(currentEntitySelected, component, componentType)
Creates inputs based on the component type and populates them.
"""
function ShowComponentProperties(currentEntitySelected, component, componentType)

    if componentType == "Transform"
        fieldsInComponent=fieldnames(JulGame.TransformModule.Transform);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Collider"
        fieldsInComponent=fieldnames(JulGame.ColliderModule.Collider);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Rigidbody"
        fieldsInComponent=fieldnames(JulGame.RigidbodyModule.Rigidbody);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Animator"
        fieldsInComponent=fieldnames(JulGame.AnimatorModule.Animator);
        ShowAnimatorProperties(fieldsInComponent, currentEntitySelected)
        # for i = 1:length(fieldsInComponent)
        #     ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        # end
    elseif componentType == "Animation"
        fieldsInComponent=fieldnames(JulGame.AnimationModule.Animation);
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "Sprite"
        fieldsInComponent=fieldnames(JulGame.SpriteModule.Sprite);
        ShowSpriteProperties(fieldsInComponent, currentEntitySelected)
    elseif componentType == "SoundSource"
        fieldsInComponent=fieldnames(JulGame.SoundSourceModule.SoundSource);
        ShowSoundSourceProperties(fieldsInComponent, currentEntitySelected)
    end

end

function ShowComponentPropertyInput(currentEntitySelected, component, componentType, componentField, name = C_NULL)
    if currentEntitySelected === nothing 
        return
    end
    itemToUpdateType = getType(currentEntitySelected)
    if itemToUpdateType == "Entity"
        itemToUpdate = currentEntitySelected.getComponent(componentType)
    else
        itemToUpdate = currentEntitySelected
    end

    componentFieldValue = getfield(component, componentField)
    componentFieldType = getType(componentFieldValue)

    if componentFieldType == "Vector2f"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue.x)
        y = Cfloat(componentFieldValue.y)
        @c CImGui.InputFloat("$(componentField) x", &x, 1)
        @c CImGui.InputFloat("$(componentField) y", &y, 1)
        itemToUpdate.setVector2fValue(componentField,convert(Float64, x),convert(Float64, y))

    elseif componentFieldType == "Bool" 
        @c CImGui.Checkbox("$(componentField)", &componentFieldValue)
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "String"
        buf = "$(componentFieldValue)"*"\0"^(64)
        CImGui.InputText("$(componentField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = 1:length(buf)
            if Int(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "Float64"
        CImGui.Text(componentField)
        x = Cfloat(componentFieldValue)
        @c CImGui.InputFloat("$(componentField)", &x, 1)
        setfield!(itemToUpdate,componentField,componentFieldValue)
    
    elseif componentFieldType == "Int64"
        CImGui.Text(componentField)
        x = Cint(componentFieldValue)
        @c CImGui.InputInt("$(componentField)", &x, 1)
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "Vector4"
        vec4i = Cint[componentFieldValue.x, componentFieldValue.y, componentFieldValue.w, componentFieldValue.h]
        @c CImGui.InputInt4("input int4", vec4i)
        
    elseif componentFieldType == "Array" # Then we need to unpack the nested items
        for i = 1:length(componentFieldValue) 
            nestedType = "$(typeof(componentFieldValue[i]).name.wrapper)"
            nestedFieldType = String(split(nestedType, '.')[length(split(nestedType, '.'))])
            if CImGui.TreeNode("$(nestedFieldType) $(i)")
                CImGui.Button("Delete") && (deleteat!(componentFieldValue, i); break;)
                try
                    CImGui.Button("Add") && componentFieldValue[i].appendArray()
                catch e
                    println(e)
                end
                if nestedFieldType in JulGameComponents
                    ShowComponentProperties(componentFieldValue[i], componentFieldValue[i], nestedFieldType)
                else
                    try
                        currentEntitySelected.updateArrayValue(ShowArrayPropertyInput(componentFieldValue, i), componentField, i)
                    catch e
                        println(e)
                    end
                end
                CImGui.TreePop()
            end
        end

    end

end

function ShowArrayPropertyInput(arr, index) 
    type = getType(arr[index])
    if type == "Vector4"
        vec = arr[index]
        vec4i = Cint[vec.x, vec.y, vec.w, vec.h]
        @c CImGui.InputInt4("input int4", vec4i)
        return JulGame.Math.Vector4(vec4i[1], vec4i[2], vec4i[3], vec4i[4])
    end
end

function getType(item)
    componentFieldType = "$(typeof(item).name.wrapper)"
    return String(split(componentFieldType, '.')[length(split(componentFieldType, '.'))])
end

function ShowAnimatorProperties(animatorFields, currentEntitySelected)
    try
        for field in animatorFields
            fieldString = "$(field)"
            
            if fieldString == "animations"
                animationFields=fieldnames(JulGame.AnimationModule.Animation);
                animations = currentEntitySelected.getAnimator().animations

                CImGui.Button("Add Animation") && field.appendArray()
                for i = 1:length(animations) 
                    if CImGui.TreeNode("animation $(i)")
                        for j = 1:length(animationFields)
                            animationFieldString = "$(animationFields[j])"
                            if animationFieldString == "animatedFPS"
                                x = Cint(animations[i].animatedFPS)
                                @c CImGui.InputInt("$(animationFieldString) $(j)", &x, 1)
                                currentEntitySelected.getAnimator().animations[i].animatedFPS = x
                            elseif animationFieldString == "frames"
                                try
                                    CImGui.Button("Add Frame") && animations[i].appendArray()
                                    CImGui.Button("Delete") && (deleteat!(animations, i); break;)
                                    for k = 1:length(animations[i].frames)
                                        if CImGui.TreeNode("frame $(k)")
                                            vec = animations[i].frames[k]
                                            vec4i = Cint[vec.x, vec.y, vec.w, vec.h]
                                            @c CImGui.InputInt4("frame input $(k)", vec4i)
                                            currentEntitySelected.getAnimator().animations[i].updateArrayValue(JulGame.Math.Vector4(vec4i[1], vec4i[2], vec4i[3], vec4i[4]), animationFields[j], k)
                                            CImGui.TreePop()
                                        end
                                    end
                                catch e
                                    println(e)
                                    Base.show_backtrace(stdout, catch_backtrace())
                                end
                            end
                        end
                        CImGui.TreePop()
                    end
                end
            elseif fieldString == "currentAnimation"
            end  
        end
    catch e
        println(e)
        Base.show_backtrace(stdout, catch_backtrace())
    end
end

function ShowSpriteProperties(spriteFields, currentEntitySelected)
    for field in spriteFields
        fieldString = "$(field)"

        if fieldString == "imagePath"
            buf = "$(currentEntitySelected.getComponent("Sprite").imagePath)"*"\0"^(64)
            CImGui.InputText("Image Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = 1:length(buf)
                if Int(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            currentEntitySelected.getComponent("Sprite").imagePath = currentTextInTextBox
            CImGui.Button("Load Image") && (currentEntitySelected.getComponent("Sprite").loadImage(currentTextInTextBox))
        elseif fieldString == "isFlipped"
            isFlipped = currentEntitySelected.getComponent("Sprite").isFlipped
            @c CImGui.Checkbox("isFlipped", &isFlipped)
            currentEntitySelected.getComponent("Sprite").isFlipped = isFlipped
        end  
    end
end

function ShowSpriteProperties(spriteFields, currentEntitySelected)
    for field in spriteFields
        fieldString = "$(field)"

        if fieldString == "imagePath"
            buf = "$(currentEntitySelected.getComponent("Sprite").imagePath)"*"\0"^(64)
            CImGui.InputText("Image Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = 1:length(buf)
                if Int(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            currentEntitySelected.getComponent("Sprite").imagePath = currentTextInTextBox
            CImGui.Button("Load Image") && (currentEntitySelected.getComponent("Sprite").loadImage(currentTextInTextBox))
        elseif fieldString == "isFlipped"
            isFlipped = currentEntitySelected.getComponent("Sprite").isFlipped
            @c CImGui.Checkbox("isFlipped", &isFlipped)
            currentEntitySelected.getComponent("Sprite").isFlipped = isFlipped
        end  
    end
end

function ShowSoundSourceProperties(soundFields, currentEntitySelected)
    for field in soundFields
        fieldString = "$(field)"

        if fieldString == "path"
            CImGui.Text("Sound Path")
            buf = "$(currentEntitySelected.getComponent("SoundSource").path)"*"\0"^(64)
            CImGui.InputText("Sound Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = 1:length(buf)
                if Int(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            currentEntitySelected.getComponent("SoundSource").path = currentTextInTextBox
            CImGui.Button("Load Sound") && (currentEntitySelected.getComponent("SoundSource").loadSound(currentTextInTextBox, false))
            CImGui.Button("Load Music") && (currentEntitySelected.getComponent("SoundSource").loadSound(currentTextInTextBox, true))
        end  
    end
end