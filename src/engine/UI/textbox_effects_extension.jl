module TextBoxEffectsExtension
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    using ..UI.TextStyleModule
    export apply_effects!, set_dynamic_text

    """
        apply_effects!(tb::TextBox, style::TextStyle)

    Applies a `TextStyle` to a `TextBox` and triggers re-rendering.
    Only re-renders if the style has actually changed to avoid redundant work.
    """
    function apply_effects!(tb, style::TextStyleModule.TextStyle)
        # Check if style has changed to avoid redundant re-rendering in immediate mode
        needsUpdate = false
        
        if tb.textStyle !== style
            tb.textStyle = style
            needsUpdate = true
        end
        
        newFontPath = style.font != "" ? style.font : tb.fontPath
        if tb.fontPath != newFontPath || tb.fontSize != style.size
            tb.fontPath = newFontPath
            tb.fontSize = style.size
            needsUpdate = true
        end
        
        if tb.color != style.baseColor
            tb.color = style.baseColor
            needsUpdate = true
        end
        
        # Only re-render if something changed
        if needsUpdate
            @debug("Applying effects to $(tb.name), re-rendering")
            UI.rerender_text(tb)  # rerender_text handles font loading internally
        end
        
        return tb
    end

    """
        set_dynamic_text(tb::TextBox, flag::Bool)

    Marks this TextBox as dynamic to alter caching strategy for effects.
    """
    function set_dynamic_text(tb, flag::Bool)
        tb.isDynamic = flag
        if tb.textStyle !== nothing
            tb.textStyle.isDynamic = flag
        end
    end
end


