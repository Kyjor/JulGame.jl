CustomMappings = Dict{String, Dict{Symbol, Symbol}}(
    "InternalAnimator" => Dict{Symbol, Symbol}(),
    "InternalCollider" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),  
    "InternalRigidbody" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),
    "InternalSoundSource" => Dict{Symbol, Symbol}(
        :path => :path,
    ),
    "InternalSprite" => Dict{Symbol, Symbol}(
        :imagePath => :path,
    ),
    "ScreenButton" => Dict{Symbol, Symbol}(
        :buttonUpSpritePath => :pathUp,
        :buttonDownSpritePath => :pathDown,
    ),
    "TextBox" => Dict{Symbol, Symbol}(
        :fontPath => :path,
    ),
    "Transform" => Dict{Symbol, Symbol}(),
    "UIImage" => Dict{Symbol, Symbol}(
        :path => :path,
    ),
    "UIElement" => Dict{Symbol, Symbol}(),
)

function show_custom_field_mapping(structure::EditableStructure, field::Symbol, customDisplay::Symbol, value::Any)
    structureType = typeof(structure)
    if customDisplay == :path || customDisplay == :pathUp || customDisplay == :pathDown
        pathType = if isa(structure, JulGame.SpriteModule.InternalSprite) || isa(structure, JulGame.UI.ScreenButtonModule.ScreenButton) || isa(structure, JulGame.UI.UIImageModule.UIImage)
            "images"
        elseif isa(structure, JulGame.UI.TextBoxModule.TextBox)
            "fonts"
        elseif isa(structure, JulGame.SoundSourceModule.InternalSoundSource)
            "sounds"
        end

        CImGui.Text("Path: $(value)")
        if isa(structure, JulGame.UI.TextBoxModule.TextBox)
            if strip(String(structure.fontPath)) == "" || joinpath(strip(String(structure.fontPath))) == joinpath("FiraCode-Regular.ttf")
                filePath = joinpath("FiraCode-Regular.ttf")
            end
        end
        # Use the new file finder modal
        if CImGui.Button("Browse...")
            @debug "Browse button clicked for pathType: $pathType"
            open_file_finder_modal(joinpath(JulGame.BasePath, "assets", pathType), pathType, "Select $(pathType) File")
        end
        
        # Check if a file was selected from the modal (only when modal is closed)
        if !is_file_finder_open() && get_file_finder_result() != ""
            selected_file = get_file_finder_result()
            @debug "File selected from modal: $selected_file for pathType: $pathType"
            
            # Verify the file type matches what we expect
            state = JulGame.EditorState["file_finder"]
            if state.file_type != pathType
                @warn "File type mismatch: expected $pathType but got $(state.file_type), ignoring selection"
                state.selected_file = ""
                return
            end
            
            # Extract relative path
            filePath = replace(selected_file, joinpath(JulGame.BasePath, "assets", pathType) => "")
            if filePath[1] == '/' || filePath[1] == '\\'
                filePath = filePath[2:end]
            end
            
            @debug "Setting field $field to: $filePath"

            setproperty!(structure, field, filePath)
            if isa(structure, JulGame.SpriteModule.InternalSprite) || isa(structure, JulGame.UI.UIImageModule.UIImage)
                JulGame.load_image(structure, filePath)
            elseif isa(structure, JulGame.UI.ScreenButtonModule.ScreenButton)
                UI.load_button_sprite_editor(structure, filePath, customDisplay == :pathUp)
            elseif isa(structure, JulGame.SoundSourceModule.InternalSoundSource)
                Component.load_sound(structure, filePath, structure.isMusic)
            elseif isa(structure, JulGame.UI.TextBoxModule.TextBox)
                UI.load_font(structure, filePath)
            end
            
            # Clear the result to prevent re-processing
            state.selected_file = ""
        end
    end
end