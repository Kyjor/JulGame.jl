module UI
    using ..JulGame
    using ..JulGame.Math

    import ..JulGame: 
        add_click_event,
        center_text,
        destroy,
        handle_event,
        initialize,
        load_button_sprite_editor,
        load_font,
        render, 
        rerender_text,
        set_color,
        set_position,
        update_button_text,
        update_font_size

    include("ScreenButton.jl")
    include("TextBox.jl")
    #include("Draggable.jl")
    include("Rectangle.jl")
    include("Line.jl")
    include("Circle.jl")
    include("ProgressBar.jl")
    include("ImmediateUI.jl")
    include("Factory.jl")
    
    export ScreenButtonModule
    export TextBoxModule
    export ImmediateUIModule
    #export DraggableModule
    export RectangleModule
    export LineModule
    export CircleModule
    export ProgressBarModule

    export create_text_box, create_screen_button, create_rectangle, create_line, create_circle, create_progress_bar, make_draggable
    export constrain_to_window, constrain_to_rect

    # Re-export UI components
    export TextBox, ScreenButton, Rectangle, Line, Circle, ProgressBar#, Draggable
end
