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

    const anchor_types = JulGame.Enum{Any}(
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

    include("UIElement.jl")
    include("ScreenButton.jl")
    include("TextBox.jl")
    include("Rectangle.jl")
    include("Canvas.jl")
    include("UIImage.jl")
    include("ImmediateUI.jl")

    using .ScreenButtonModule: ScreenButton
    using .TextBoxModule: TextBox
    using .RectangleModule: Rectangle
    using .CanvasModule: Canvas
    using .UIImageModule: UIImage

    export ScreenButtonModule
    export TextBoxModule
    export ImmediateUIModule
    export RectangleModule
    export CanvasModule
    export UIImageModule

    export constrain_to_window, constrain_to_rect

    # Re-export UI components
    export TextBox, ScreenButton, Rectangle, Canvas, UIImage
end
