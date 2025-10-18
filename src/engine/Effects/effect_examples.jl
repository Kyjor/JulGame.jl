module EffectExamplesModule
    import ...JulGame
    const Math = JulGame.Math
    using ..EffectsModule
    using ..EffectRendererModule
    using ..EffectCacheModule

    export create_button_with_effects, create_panel_with_effects, create_text_with_effects, create_highlighted_sprite, create_text_with_inherited_colors

    """
    Create a button with bevel and shadow effects
    """
    function create_button_with_effects(position::Math.Vector2, size::Math.Vector2, text::String="Button")
        # Create rectangle
        button = UI.create_rectangle(position, size, (100, 150, 200, 255))
        
        # Apply button effects
        button_effects = [
            BevelEffect(depth=3, angle=135, highlight_color=(255,255,255,120), shadow_color=(0,0,0,150)),
            DropShadowEffect(distance=4, angle=135, blur_radius=6, color=(0,0,0,128))
        ]
        apply_effects!(button, button_effects)
        
        # Add text on top
        text_element = UI.create_textbox(text, position=position + Math.Vector2(10, 10), color=(255,255,255,255))
        text_effects = [
            StrokeEffect(width=1, color=(0,0,0,255)),
            OuterGlowEffect(radius=2, color=(255,255,255,100))
        ]
        apply_effects!(text_element, text_effects)
        
        return button, text_element
    end

    """
    Create a panel with glow and shadow effects
    """
    function create_panel_with_effects(position::Math.Vector2, size::Math.Vector2)
        # Create rectangle
        panel = UI.create_rectangle(position, size, (50, 50, 60, 255))
        
        # Apply panel effects
        panel_effects = [
            OuterGlowEffect(radius=8, color=(100,100,120,140), blur=0.7),
            DropShadowEffect(distance=6, angle=135, blur_radius=8, color=(0,0,0,100)),
            BevelEffect(depth=1, angle=135, highlight_color=(255,255,255,50), shadow_color=(0,0,0,100))
        ]
        apply_effects!(panel, panel_effects)
        
        return panel
    end

    """
    Create text with stroke and glow effects
    """
    function create_text_with_effects(position::Math.Vector2, text::String, color::NTuple{4, Int}=(255,255,255,255))
        # Create text
        text_element = UI.create_textbox(text, position=position, color=color)
        
        # Apply text effects
        text_effects = [
            StrokeEffect(width=2, color=(0,0,0,255)),
            OuterGlowEffect(radius=4, color=(100,100,120,100), blur=0.5),
            InnerGlowEffect(radius=2, color=(255,255,255,80))
        ]
        apply_effects!(text_element, text_effects)
        
        return text_element
    end

    """
    Create a sprite with highlight effects
    """
    function create_highlighted_sprite(entity, image_path::String, position::Math.Vector2f)
        # Create sprite
        sprite = Component.Sprite(entity, image_path, position=position)
        
        # Apply highlight effects
        highlight_effects = [
            OuterGlowEffect(radius=12, color=(255,255,0,150), blur=1.0),
            DropShadowEffect(distance=3, angle=135, blur_radius=4, color=(255,255,0,100))
        ]
        apply_effects!(sprite, highlight_effects)
        
        return sprite
    end

    """
    Create a distressed/grunge effect
    """
    function create_distressed_effect(target)
        distressed_effects = [
            RoughEdgeEffect(amount=4, seed=123, erosion=true),
            StrokeEffect(width=1, color=(100,100,100,200)),
            DropShadowEffect(distance=2, angle=135, blur_radius=3, color=(0,0,0,150))
        ]
        apply_effects!(target, distressed_effects)
        return target
    end

    """
    Create a neon glow effect
    """
    function create_neon_effect(target, glow_color::NTuple{4, Int}=(0,255,255,200))
        neon_effects = [
            OuterGlowEffect(radius=15, color=glow_color, blur=1.5),
            InnerGlowEffect(radius=3, color=glow_color),
            DropShadowEffect(distance=8, angle=135, blur_radius=12, color=glow_color)
        ]
        apply_effects!(target, neon_effects)
        return target
    end

    """
    Create a 3D embossed effect
    """
    function create_embossed_effect(target)
        embossed_effects = [
            BevelEffect(depth=4, angle=135, highlight_color=(255,255,255,150), shadow_color=(0,0,0,200)),
            DropShadowEffect(distance=3, angle=135, blur_radius=4, color=(0,0,0,100))
        ]
        apply_effects!(target, embossed_effects)
        return target
    end

    """
    Create a gradient text effect
    """
    function create_gradient_text(position::Math.Vector2, text::String)
        # Create text
        text_element = UI.create_textbox(text, position=position, color=(255,255,255,255))
        
        # Create gradient stops
        gradient_stops = [
            (position=0.0, color=(255,0,0,255)),    # Red at start
            (position=0.5, color=(0,255,0,255)),    # Green in middle
            (position=1.0, color=(0,0,255,255))     # Blue at end
        ]
        
        # Apply gradient effects
        gradient_effects = [
            GradientEffect(gradientType="LinearGradient", stops=gradient_stops, angle=0.0),
            StrokeEffect(width=2, color=(0,0,0,255)),
            OuterGlowEffect(radius=6, color=(255,255,255,100), blur=0.8)
        ]
        apply_effects!(text_element, gradient_effects)
        
        return text_element
    end

    """
    Create a textured effect
    """
    function create_textured_effect(target, texture_path::String)
        textured_effects = [
            TextureFillEffect(texturePath=texture_path, tile=true, blendMode=1, opacity=180),
            BevelEffect(depth=2, angle=135, highlight_color=(255,255,255,100), shadow_color=(0,0,0,120))
        ]
        apply_effects!(target, textured_effects)
        return target
    end

    """
    Create a complex multi-layered effect
    """
    function create_complex_effect(target)
        complex_effects = [
            # Base texture
            TextureFillEffect(texturePath="metal_texture.png", tile=true, blendMode=1, opacity=150),
            # Bevel for 3D look
            BevelEffect(depth=3, angle=135, highlight_color=(255,255,255,120), shadow_color=(0,0,0,150)),
            # Inner glow for depth
            InnerGlowEffect(radius=4, color=(100,150,255,100)),
            # Outer glow for highlight
            OuterGlowEffect(radius=8, color=(255,255,255,80), blur=0.6),
            # Rough edges for texture
            RoughEdgeEffect(amount=2, seed=456, erosion=true),
            # Final shadow
            DropShadowEffect(distance=6, angle=135, blur_radius=8, color=(0,0,0,120))
        ]
        apply_effects!(target, complex_effects)
        return target
    end

    """
    Apply a predefined style to any target
    """
    function apply_button_style(target)
        return apply_style!(target, create_button_style())
    end

    function apply_panel_style(target)
        return apply_style!(target, create_panel_style())
    end

    function apply_text_style(target)
        return apply_style!(target, create_text_style())
    end

    function apply_highlight_style(target)
        return apply_style!(target, create_highlight_style())
    end

    function apply_distressed_style(target)
        return apply_style!(target, create_distressed_style())
    end
    
    """
    Create text with effects that inherit the original text color
    """
    function create_text_with_inherited_colors(position::Math.Vector2, text::String, text_color::NTuple{4, Int}=(255, 100, 100, 255))
        # Create text with a specific color
        text_element = UI.create_textbox(text, position=position, color=text_color)
        
        # Apply effects that inherit the original color
        inherited_effects = [
            StrokeEffect(width=2, color=INHERIT_COLOR),  # Stroke uses original text color
            OuterGlowEffect(radius=4, color=INHERIT_COLOR),  # Glow uses original text color
            DropShadowEffect(distance=3, angle=135, blur_radius=4, color=(0,0,0,128))  # Shadow uses black
        ]
        apply_effects!(text_element, inherited_effects)
        
        return text_element
    end
end
