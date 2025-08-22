module UI
    using ..JulGame
    import ..JulGame: 
        add_click_event,
        center_text,
        destroy,
        handle_event,
        initialize,
        load_button_sprite_editor,
        load_font,
        load_image_sprite_editor,
        render, 
        rerender_text,
        set_color,
        set_position,
        update_font_size

    include("ScreenButton.jl")
    include("TextBox.jl")
    include("Image.jl")
    
    export ScreenButtonModule
    export TextBoxModule
    export ImageModule
end
