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
        filePathMenuValue = display_files(joinpath(JulGame.BasePath, "assets", pathType), pathType, menu_id = "$(field)")
        if filePathMenuValue != ""
            filePath = replace(filePathMenuValue, joinpath(JulGame.BasePath, "assets", pathType) => "")
            if filePath[1] == '/' || filePath[1] == '\\'
                filePath = filePath[2:end]
            end

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
        end
    end
end