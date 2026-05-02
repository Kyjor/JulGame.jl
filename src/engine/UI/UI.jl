                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           module UI
    using ..JulGame
    using ..JulGame.Math

    import ..JulGame: 
        add_click_event,
        add_hover_enter_event,
        add_hover_exit_event,
        apply_effects!,
        request_effects_refresh!,
        align_to_anchor,
        destroy,
        duplicate,
        handle_event,
        handle_hover_event,
        handle_window_resize,
        initialize,
        load_button_sprite_editor,
        load_font,
        load_image,
        render, 
        rerender_text,
        set_color,
        set_position,
        update_button_text,
        update_font_size

    const ANCHOR_STATE_SYMBOLS = (
        :center,
        :top,
        :bottom,
        :left,
        :right,
        :topLeft,
        :topRight,
        :bottomLeft,
        :bottomRight,
        :centerLeft,
        :centerRight,
        :centerTop,
        :centerBottom,
        :none
    )
    const anchor_types = JulGame.Enum{Any}(ANCHOR_STATE_SYMBOLS...)

    function canvas_active_for_input end

    #include("Draggable.jl")
    include("UIElement.jl")
    include("ScreenButton.jl")
    include("TextBox.jl")
    include("Rectangle.jl")
    include("Line.jl")
    include("Circle.jl")
    include("ProgressBar.jl")
    include("Canvas.jl")
    include("UIImage.jl")
    include("ImmediateUI.jl")
    include("Factory.jl")
    include("InputEventDispatch.jl")
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
    export TextStyleModule
    export ScreenButtonModule
    export TextBoxModule
    export ImmediateUIModule
    #export DraggableModule
    export RectangleModule
    export LineModule
    export CircleModule
    export ProgressBarModule
    export CanvasModule
    export UIImageModule

    export create_text_box, create_screen_button, create_rectangle, create_line, create_circle, create_progress_bar, make_draggable
    export input_ui_is_active, input_ui_force_click_check, input_ui_name, input_ui_is_hovered, input_ui_set_isHovered!, input_ui_layer, input_ui_position, input_ui_size
    export sort_reversed_ui_by_layer_for_input, canvas_active_for_input, relationship_instance
    export constrain_to_window, constrain_to_rect

    # Re-export UI components
    export TextBox, ScreenButton, Rectangle, Line, Circle, ProgressBar, Canvas, UIImage#, Draggable
end
