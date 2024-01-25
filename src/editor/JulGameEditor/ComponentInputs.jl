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
        fieldsInComponent=fieldnames(JulGame.TransformModule.Transform)
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "InternalCollider"
        fieldsInComponent=fieldnames(JulGame.ColliderModule.InternalCollider)
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "InternalRigidbody"
        fieldsInComponent=fieldnames(JulGame.RigidbodyModule.InternalRigidbody)
        fieldsToSkip = String["acceleration", "grounded", "velocity"]
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "InternalAnimator"
        fieldsInComponent=fieldnames(JulGame.AnimatorModule.InternalAnimator)
        ShowAnimatorProperties(fieldsInComponent, currentEntitySelected)
    elseif componentType == "Animation"
        fieldsInComponent=fieldnames(JulGame.AnimationModule.Animation)
        for i = 1:length(fieldsInComponent)
            ShowComponentPropertyInput(currentEntitySelected, component, componentType, fieldsInComponent[i])
        end
    elseif componentType == "InternalSprite"
        fieldsInComponent=fieldnames(JulGame.SpriteModule.InternalSprite)
        ShowSpriteProperties(fieldsInComponent, currentEntitySelected)
    elseif componentType == "InternalSoundSource"
        fieldsInComponent=fieldnames(JulGame.SoundSourceModule.InternalSoundSource)
        ShowSoundSourceProperties(fieldsInComponent, currentEntitySelected)
    elseif componentType == "InternalShape"
        fieldsInComponent=fieldnames(JulGame.SoundSourceModule.InternalShape)
        ShowSoundSourceProperties(fieldsInComponent, currentEntitySelected)
    elseif componentType == "InternalCircleCollider"
        fieldsInComponent=fieldnames(JulGame.SoundSourceModule.InternalCircleCollider)
        ShowSoundSourceProperties(fieldsInComponent, currentEntitySelected)
    end

end

function ShowComponentPropertyInput(currentEntitySelected, component, componentType, componentField, name = C_NULL)
    if currentEntitySelected === nothing 
        return
    end
    itemToUpdateType = getType(currentEntitySelected)
    if itemToUpdateType == "Entity"
        if componentType == "Transform"
            itemToUpdate = currentEntitySelected.transform
        elseif componentType == "InternalCollider"
            itemToUpdate = currentEntitySelected.collider
        elseif componentType == "InternalRigidbody"
            itemToUpdate = currentEntitySelected.rigidbody
        elseif componentType == "InternalAnimator"
            itemToUpdate = currentEntitySelected.animator
        elseif componentType == "Animation"
            itemToUpdate = currentEntitySelected.animation
        elseif componentType == "InternalSprite"
            itemToUpdate = currentEntitySelected.sprite
        elseif componentType == "InternalSoundSource"
            itemToUpdate = currentEntitySelected.soundSource
        elseif componentType == "InternalShape"
            itemToUpdate = currentEntitySelected.shape
        elseif componentType == "InternalCircleCollider"
            itemToUpdate = currentEntitySelected.circleCollider
        end
    else
        itemToUpdate = currentEntitySelected
    end

    componentFieldValue = getfield(component, componentField)
    componentFieldType = getType(componentFieldValue)

    if componentFieldType == "_Vector2"
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
            if Int32(buf[characterIndex]) == 0 
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
    
    elseif componentFieldType == "Int32"
        CImGui.Text(componentField)
        x = Cint(componentFieldValue)
        @c CImGui.InputInt("$(componentField)", &x, 1)
        setfield!(itemToUpdate,componentField,componentFieldValue)

    elseif componentFieldType == "_Vector4"
        vec4i = Cint[componentFieldValue.x, componentFieldValue.y, componentFieldValue.z, componentFieldValue.t]
        @c CImGui.InputInt4("input int4", vec4i)
        
    elseif componentFieldType == "Vector" # Then we need to unpack the nested items
        for i = 1:length(componentFieldValue) 
            nestedType = "$(typeof(componentFieldValue[i]).name.wrapper)"
            nestedFieldType = String(split(nestedType, '.')[length(split(nestedType, '.'))])
            if CImGui.TreeNode("$(nestedFieldType) $(i)")
                CImGui.Button("Delete") && (deleteat!(componentFieldValue, i); break;)
                try
                    CImGui.Button("Add") && componentFieldValue[i].appendArray()
                catch e
                    rethrow(e)
                end
                if nestedFieldType in JulGameComponents
                    ShowComponentProperties(componentFieldValue[i], componentFieldValue[i], nestedFieldType)
                else
                    try
                        currentEntitySelected.updateArrayValue(ShowArrayPropertyInput(componentFieldValue, i), componentField, i)
                    catch e
                        rethrow(e)
                    end
                end
                CImGui.TreePop()
            end
        end

    end

end

function ShowArrayPropertyInput(arr, index) 
    type = getType(arr[index])
    if type == "_Vector4"
        vec = arr[index]
        vec4i = Cint[vec.x, vec.y, vec.z, vec.t]
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
                animations = currentEntitySelected.animator.animations

                CImGui.Button("Add Animation") && currentEntitySelected.animator.appendArray()
                for i = 1:length(animations) 
                    if CImGui.TreeNode("animation $(i)")
                        for j = 1:length(animationFields)
                            animationFieldString = "$(animationFields[j])"
                            if animationFieldString == "animatedFPS"
                                x = Cint(animations[i].animatedFPS)
                                @c CImGui.InputInt("$(animationFieldString) $(j)", &x, 1)
                                currentEntitySelected.animator.animations[i].animatedFPS = x
                            elseif animationFieldString == "frames"
                                try
                                    CImGui.Button("Add Frame") && animations[i].appendArray()
                                    CImGui.Button("Delete") && (deleteat!(animations, i); break;)
                                    for k = 1:length(animations[i].frames)
                                        if CImGui.TreeNode("frame $(k)")
                                            vec = animations[i].frames[k]
                                            vec4i = Cint[vec.x, vec.y, vec.z, vec.t]
                                            @c CImGui.InputInt4("frame input $(k)", vec4i)
                                            currentEntitySelected.animator.animations[i].updateArrayValue(JulGame.Math.Vector4(Int32(vec4i[1]), Int32(vec4i[2]), Int32(vec4i[3]), Int32(vec4i[4])), animationFields[j], Int32(k))
                                            CImGui.TreePop()
                                        end
                                    end
                                catch e
                                    rethrow(e)
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
        rethrow(e)
    end
end

function ShowSpriteProperties(spriteFields, currentEntitySelected)
    for field in spriteFields
        fieldString = "$(field)"

        if fieldString == "imagePath"
            buf = "$(currentEntitySelected.sprite.imagePath)"*"\0"^(64)
            CImGui.InputText("Image Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = 1:length(buf)
                if Int32(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            currentEntitySelected.sprite.imagePath = currentTextInTextBox
            CImGui.Button("Load Image") && (currentEntitySelected.sprite.loadImage(currentTextInTextBox))
        elseif fieldString == "isFlipped"
            isFlipped = currentEntitySelected.sprite.isFlipped
            @c CImGui.Checkbox("isFlipped", &isFlipped)
            currentEntitySelected.sprite.isFlipped = isFlipped
        elseif fieldString == "crop"
            vec = currentEntitySelected.sprite.crop == C_NULL ? JulGame.Math.Vector4(0,0,0,0) : currentEntitySelected.sprite.crop
            vec4i = Cint[vec.x, vec.y, vec.z, vec.t]
            @c CImGui.InputInt4("input int4", vec4i)

            currentEntitySelected.sprite.crop = (vec4i[1] == 0 && vec4i[2] == 0 && vec4i[3] == 0 && vec4i[4] == 0) ? C_NULL : JulGame.Math.Vector4(vec4i[1], vec4i[2], vec4i[3], vec4i[4])
        elseif fieldString == "layer"
            x = Cint(currentEntitySelected.sprite.layer)
            @c CImGui.InputInt("layer", &x, 1)
            currentEntitySelected.sprite.layer = x

        elseif fieldString == "pixelsPerUnit"
            x = Cint(currentEntitySelected.sprite.pixelsPerUnit)
            @c CImGui.InputInt("pixelsPerUnit", &x, 1)
            currentEntitySelected.sprite.pixelsPerUnit = x
        end  
    end
end

function ShowSoundSourceProperties(soundFields, currentEntitySelected)
    for field in soundFields
        fieldString = "$(field)"

        if fieldString == "path"
            CImGui.Text("Sound Path")
            buf = "$(currentEntitySelected.soundSource.path)"*"\0"^(64)
            CImGui.InputText("Sound Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = 1:length(buf)
                if Int32(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            currentEntitySelected.soundSource.path = currentTextInTextBox
            CImGui.Button("Load Sound") && (currentEntitySelected.soundSource.loadSound(currentTextInTextBox, false))
            CImGui.Button("Load Music") && (currentEntitySelected.soundSource.loadSound(currentTextInTextBox, true))
        end  
    end
end