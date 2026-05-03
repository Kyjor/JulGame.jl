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

    # JuliaC `--trim`: add methods to `JulGame.align_to_anchor` (CommonFunctions stub) so calls are not a separate `UI.align_to_anchor` generic that the verifier maps to `align_to_anchor(::IUIElement)`.
    const SceneAlignableUI = Union{
        TextBoxModule.TextBox,
        ScreenButtonModule.ScreenButton,
        RectangleModule.Rectangle,
        LineModule.Line,
        CircleModule.Circle,
        ProgressBarModule.ProgressBar,
        CanvasModule.Canvas,
        UIImageModule.UIImage,
    }

    function JulGame.align_to_anchor(this::SceneAlignableUI)::Nothing
        main = JulGame.current_main()
        sc = getfield(main, :scene)
        cam = getfield(sc, :camera)
        if cam === nothing
            @debug "No camera found in scene"
            return nothing
        end

        add_relationship_if_not_exists(this)
        tinst = relationship_instance(this)
        tw = getfield(tinst, :size)::JulGame.Math._Vector2{Int32}
        thx = getfield(tw, :x)::Int32
        thy = getfield(tw, :y)::Int32
        tao = getfield(tinst, :anchorOffset)::JulGame.Math._Vector2{Int32}
        t_aox = Float64(getfield(tao, :x)::Int32)
        t_aoy = Float64(getfield(tao, :y)::Int32)
        anch = getfield(tinst, :anchor)
        if anch === nothing
            try
                anch = getfield(this, :anchor)::JulGame.Enum{Any}
            catch
                @debug "align_to_anchor: missing anchor on $(getfield(tinst, :name)::String)"
                return nothing
            end
        end
        cur = getfield(anch::JulGame.Enum{Any}, :current_state)::Symbol

        sx::Float64
        sy::Float64
        ox::Float64
        oy::Float64
        par = getfield(tinst, :parent)
        if par === nothing
            cam_sz = getfield(cam, :size)::JulGame.Math._Vector2{Int32}
            sx = Float64(getfield(cam_sz, :x)::Int32)
            sy = Float64(getfield(cam_sz, :y)::Int32)
            ox = 0.0
            oy = 0.0
        elseif par isa JulGame.IUIElement
            add_relationship_if_not_exists(par)
            pinst = relationship_instance(par)
            p_sz = getfield(pinst, :size)::JulGame.Math._Vector2{Int32}
            p_pos = getfield(pinst, :position)::JulGame.Math._Vector2{Int32}
            sx = Float64(getfield(p_sz, :x)::Int32)
            sy = Float64(getfield(p_sz, :y)::Int32)
            ox = Float64(getfield(p_pos, :x)::Int32)
            oy = Float64(getfield(p_pos, :y)::Int32)
        elseif hasfield(typeof(par), :lastRenderedScreenSize) && hasfield(typeof(par), :lastRenderedScreenPosition)
            lrs = getfield(par, :lastRenderedScreenSize)
            lrp = getfield(par, :lastRenderedScreenPosition)
            if lrs === nothing || lrp === nothing
                @debug "No last rendered screen size or position found for parent of $(getfield(tinst, :name)::String)"
                return nothing
            end
            lrsf = lrs::JulGame.Math._Vector2{Float64}
            lrpf = lrp::JulGame.Math._Vector2{Float64}
            sx = getfield(lrsf, :x)::Float64
            sy = getfield(lrsf, :y)::Float64
            ox = getfield(lrpf, :x)::Float64
            oy = getfield(lrpf, :y)::Float64
        else
            @debug "align_to_anchor: parent type has no layout for $(getfield(tinst, :name)::String)"
            return nothing
        end

        fx = Float64(thx)
        fy = Float64(thy)

        if cur === :center
            _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
        elseif cur === :top
            _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + t_aoy)
        elseif cur === :bottom
            _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + sy - fy + t_aoy)
        elseif cur === :left
            _align_set_position_cells!(tinst, ox + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
        elseif cur === :right
            _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
        elseif cur === :topLeft
            _align_set_position_cells!(tinst, ox + t_aox, oy + t_aoy)
        elseif cur === :topRight
            _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + t_aoy)
        elseif cur === :bottomLeft
            _align_set_position_cells!(tinst, ox + t_aox, oy + sy - fy + t_aoy)
        elseif cur === :bottomRight
            _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + sy - fy + t_aoy)
        elseif cur === :centerLeft
            _align_set_position_cells!(tinst, ox + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
        elseif cur === :centerRight
            _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
        elseif cur === :centerTop
            _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + t_aoy)
        elseif cur === :centerBottom
            _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + sy - fy + t_aoy)
        elseif cur === :none
            @debug "No anchor set for textbox $(getfield(tinst, :name)::String)"
        else
            @error "Invalid anchor state: $(cur)"
        end
        return nothing
    end
end
