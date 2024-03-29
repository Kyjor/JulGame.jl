module UI
    using ..JulGame
    import ..JulGame: 
        add_click_event,
        center_text,
        destroy,
        handle_event,
        initialize,
        render,
        set_color,
        set_parent,
        set_position,
        set_vector2_value,
        update_text


    include("ScreenButton.jl")
    include("TextBox.jl")
    
    export ScreenButtonModule
    export TextBoxModule
end
