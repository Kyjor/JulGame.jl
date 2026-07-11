using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame
using JulGame.Math
using JulGame.UI
using FileWatching

"""
        show_animator_properties(animator, animation_window_dict, animator_preview_dict)

Display the properties of an animator object in the user interface.

# Arguments
- `animator`: The animator object to display properties for.

"""
function show_animator_properties(animator, animation_window_dict, animator_preview_dict)
    try
        for field in fieldnames(typeof(animator))
            fieldString = "$(field)"
            
            if fieldString == "animations"
                animationFields=fieldnames(JulGame.AnimationModule.Animation);
                animations = animator.animations
                currentRenderTime = SDL2.SDL_GetTicks()

                CImGui.Button("Add Animation") && Component.append_array(animator)
                for i = eachindex(animations) 
                    if animator.parent.sprite !== nothing
                        animator_preview_dict_key = "animation-$(animator.parent.id)-$(i)"
                        animator_preview_dict_info = Ref(Dict("lastFrame" => 1, "lastUpdate" => SDL2.SDL_GetTicks()))

                        if haskey(animator_preview_dict[], animator_preview_dict_key)
                            animator_preview_dict_info[] = animator_preview_dict[][animator_preview_dict_key][]
                        else
                            animator_preview_dict[][animator_preview_dict_key] = animator_preview_dict_info
                        end

                        show_image_animation_with_hover_preview(animator, animations[i], currentRenderTime, animator_preview_dict_info)
                    end
                    if CImGui.TreeNode("animation $(i)")
                        for j = eachindex(animationFields)
                            animationFieldString = "$(animationFields[j])"
                            if animationFieldString == "animatedFPS"
                                x = Cint(animations[i].animatedFPS)
                                CImGui.InputInt("$(animationFieldString) $(j)", Ref(x), 1)
                                animator.animations[i].animatedFPS = x
                            elseif animationFieldString == "frames"
                                try
                                    CImGui.Button("Add Frame") && Component.append_array(animations[i])
                                    CImGui.Button("Delete") && (deleteat!(animations, i); break;)
                                    for k = eachindex(animations[i].frames)
                                        vec = animations[i].frames[k]
                                        anim_x, anim_y, anim_w, anim_h = vec.x, vec.y, vec.z, vec.t

                                        if animator.parent.sprite !== nothing
                                            sprite = animator.parent.sprite
                                            show_image_with_hover_preview(sprite.texture, sprite.size.x, sprite.size.y, animations[i].frames[k])
                                        end
                                        if CImGui.TreeNode("frame $(k)")
                                            CImGui.Button("Delete") && (deleteat!(animations[i].frames, k); break;)
                                            if animator.parent.sprite !== nothing
                                                
                                                points = Ref(Vector{ImVec2}([ImVec2(anim_x, anim_y), ImVec2(anim_x + anim_w, anim_y + anim_h)]))
                                                scrolling = Ref(ImVec2(0.0, 0.0))
                                                adding_line = Ref(false)
                                                zoom_level = Ref(1.0)
                                                grid_step = Ref(Int32(64))

                                                # put these in a ref dictionary
                                                window_info = Ref(Dict("points" => points, "scrolling" => scrolling, "adding_line" => adding_line, "zoom_level" => zoom_level, "grid_step" => grid_step))
                                                # check if animation_window_dict has the key "frame $(k)"
                                                key = "animation-$(animator.parent.id)-$(i)-frame-$(k)"

                                                if haskey(animation_window_dict[], key)
                                                    # animation_window_dict[]["frame $(k)"][]["points"] = points
                                                    window_info[] = animation_window_dict[][key][]
                                                else
                                                    animation_window_dict[][key] = window_info
                                                end
                    
                                                sprite = animator.parent.sprite
                                                anim_x, anim_y, anim_w, anim_h = show_animation_window(key, window_info, sprite.texture, sprite.size.x, sprite.size.y)
                                                if anim_x == -1 && anim_y == -1 && anim_w == -1 && anim_h == -1
                                                    # TODO: fix this anim_x, anim_y, anim_w, anim_h = vec.x, vec.y, vec.z, vec.t
                                                    continue
                                                end
                                            end

                                            vec4i = Cint[anim_x, anim_y, anim_w, anim_h]
                                            CImGui.InputInt4("frame input $(k)", vec4i)
                                            window_info[]["points"][][1] = ImVec2(vec4i[1], vec4i[2])
                                            window_info[]["points"][][2] = ImVec2(round(vec4i[1] + vec4i[3]), round(vec4i[2] + vec4i[4]))
                                            Component.update_array_value(animations[i], JulGame.Math.Vector4(Int32(vec4i[1]), Int32(vec4i[2]), Int32(vec4i[3]), Int32(vec4i[4])), animationFields[j], Int32(k))
                                            CImGui.TreePop()
                                        end
                                    end
                                catch e
                                end
                            end
                        end
                        CImGui.TreePop()
                    end
                end
            else
                show_component_field_input(animator, field, "")
            end  
        end
    catch e
    end
end

"""
    show_sprite_fields(sprite)

Iterates over the fields of the `sprite` object and displays input fields for each field.
If the field is `imagePath`, it displays an input text field for the image path, a button to load the image,
and updates the `sprite.imagePath` field with the current text in the text box.

# Arguments
- `sprite`: The sprite object to display the fields for.

"""
function show_sprite_fields(sprite, animation_window_dict)
    for field in fieldnames(typeof(sprite))
        fieldString = "$(field)"

        if fieldString == "imagePath"
            CImGui.Text("Image: $(sprite.imagePath == "" ? "None" : sprite.imagePath)")
            
            imageMenuValue = display_files(joinpath(JulGame.BasePath, "assets", "images"), "images")
            if imageMenuValue != ""
                println("imageMenuValue: $imageMenuValue")
                # remove joinpath("assets", "images") from imageMenuValue and set it to imagePath
                imagePath = replace(imageMenuValue, joinpath(JulGame.BasePath, "assets", "images") => "")
                # remove leading / or \\ from imagePath
                if imagePath[1] == '/' || imagePath[1] == '\\'
                    imagePath = imagePath[2:end]
                end

                sprite.imagePath = imagePath
                Component.load_image(sprite, imagePath)
            end 
        elseif fieldString == "crop"
            if sprite.crop === nothing || sprite.crop == C_NULL
                sprite.crop = JulGame.Math.Vector4(0,0,0,0)
            end
            
            crop_x, crop_y, crop_w, crop_h = sprite.crop.x, sprite.crop.y, sprite.crop.z, sprite.crop.t

            points = Ref(Vector{ImVec2}([ImVec2(crop_x, crop_y), ImVec2(crop_x + crop_w, crop_y + crop_h)]))
            scrolling = Ref(ImVec2(0.0, 0.0))
            adding_line = Ref(false)
            zoom_level = Ref(1.0)
            grid_step = Ref(Int32(64))
            # put these in a ref dictionary
            window_info = Ref(Dict("points" => points, "scrolling" => scrolling, "adding_line" => adding_line, "zoom_level" => zoom_level, "grid_step" => grid_step))
            # check if animation_window_dict has the key "frame $(k)"
            key = "crop-$(sprite.parent.id)"
            if haskey(animation_window_dict[], key)
                # animation_window_dict[]["frame $(k)"][]["points"] = points
                window_info[] = animation_window_dict[][key][]
            else
                # print("Adding crop window info for: $key")
                animation_window_dict[][key] = window_info
            end

            CImGui.PushID(sprite.parent.id)
                crop_x, crop_y, crop_w, crop_h = show_animation_window("Sprite crop", window_info, sprite.texture, sprite.size.x, sprite.size.y)
                if crop_x == -1 && crop_y == -1 && crop_w == -1 && crop_h == -1
                    # TODO: fix this crop_x, crop_y, crop_w, crop_h = sprite.crop.x, sprite.crop.y, sprite.crop.z, sprite.crop.t
                    continue
                end
            CImGui.PopID()
            vec4i = Cint[crop_x, crop_y, crop_w, crop_h]
            CImGui.InputInt4("crop", vec4i)
            window_info[]["points"][][1] = ImVec2(vec4i[1], vec4i[2])
            window_info[]["points"][][2] = ImVec2(round(vec4i[1] + vec4i[3]), round(vec4i[2] + vec4i[4]))
            sprite.crop = JulGame.Math.Vector4(Int32(vec4i[1]), Int32(vec4i[2]), Int32(vec4i[3]), Int32(vec4i[4]))
        elseif fieldString == "rotation"
            show_numeric_input(sprite, field, sprite.rotation, "rotation")
        elseif fieldString == "center"
            #float that is min 0 and max 1
            if CImGui.TreeNode("center")
                x = Cfloat(sprite.center.x)
                y = Cfloat(sprite.center.y)
                modified = false
                modified |= CImGui.InputFloat("center x", Ref(x), 0.01f0, 0.1f0)
                modified |= CImGui.InputFloat("center y", Ref(y), 0.01f0, 0.1f0)
                
                if modified
                    x = Float64(x)
                    y = Float64(y)
                    x = clamp(x, 0, 1)
                    y = clamp(y, 0, 1)
                    sprite.center = Vector2f(x, y)
                end
                
                CImGui.TreePop()
            end
        elseif fieldString == "color"
            sprite.color = edit_color("SpriteColor#1", sprite.color)
        else
            show_component_field_input(sprite, field, "")
        end  
    end
end