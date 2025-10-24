module EffectExamplesModule
    import ...JulGame
    const Math = JulGame.Math
    using ..EffectsModule
    using ..EffectRendererModule
    using ..EffectCacheModule

    export create_button_with_effects, create_panel_with_effects, create_text_with_effects, create_highlighted_sprite, create_text_with_inherited_colors, create_beveled_text_examples, create_subtle_beveled_text, create_metallic_beveled_text, create_soft_beveled_text, create_simple_beveled_text

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
    
    # ============================================================================
    # COMPREHENSIVE BEVELED TEXT RENDERING EXAMPLES
    # ============================================================================
    
    """
    Create examples demonstrating the new beveled text system with various configurations
    """
    function create_beveled_text_examples()
        examples = []
        
        # Example 1: Subtle raised text for UI buttons
        subtle_text = create_subtle_beveled_text(
            Math.Vector2(50, 50), 
            "SUBTLE RAISED", 
            (100, 150, 200, 255)
        )
        push!(examples, ("Subtle Raised Text", subtle_text))
        
        # Example 2: Metallic beveled text for premium UI
        metallic_text = create_metallic_beveled_text(
            Math.Vector2(50, 100), 
            "METALLIC GOLD", 
            (255, 215, 0, 255)
        )
        push!(examples, ("Metallic Gold Text", metallic_text))
        
        # Example 3: Soft beveled text for elegant interfaces
        soft_text = create_soft_beveled_text(
            Math.Vector2(50, 150), 
            "SOFT ELEGANT", 
            (200, 200, 220, 255)
        )
        push!(examples, ("Soft Elegant Text", soft_text))
        
        # Example 4: Sharp embossed text for technical interfaces
        sharp_text = create_sharp_embossed_text(
            Math.Vector2(50, 200), 
            "SHARP EMBOSS", 
            (150, 150, 150, 255)
        )
        push!(examples, ("Sharp Embossed Text", sharp_text))
        
        return examples
    end
    
    """
    Create subtle beveled text optimized for professional UI presentation
    Recommended parameters for subtle, readable raised text effects
    """
    function create_subtle_beveled_text(position::Math.Vector2, text::String, color::NTuple{4, Int}=(255, 255, 255, 255))
        # Create base text element
        text_element = UI.create_textbox(text, position=position, color=color)
        
        # Configure subtle bevel parameters using the new BevelEffect1
        bevel_effect = BevelEffect1(
            bevel_type=OUTER_BEVEL,
            bevel_depth=2.5f0,           # Subtle depth (2-5 pixels recommended)
            bevel_width=1.5f0,           # Narrow bevel width for subtlety
            light_position=Math.Vector2(1.0, -1.0),  # Top-left lighting
            blur_radius=1.5f0,           # Soft edges (1-3 pixels recommended)
            intensity=0.6f0,              # Moderate intensity for subtlety
            
            # Subtle gradient for professional appearance
            outer_gradient=[
                GradientStop(0.0f0, (255, 255, 255, 200)),  # Bright highlight
                GradientStop(0.5f0, (220, 220, 220, 180)),  # Mid-tone
                GradientStop(1.0f0, (180, 180, 180, 160))   # Soft shadow
            ],
            
            # Minimal shadow for depth
            shadow_gradient=[
                GradientStop(0.0f0, (120, 120, 120, 100)),
                GradientStop(1.0f0, (80, 80, 80, 80))
            ]
        )
        
        # Apply the beveled text effect using the standard effects system
        apply_effects!(text_element, [bevel_effect])
        
        return text_element
    end
    
    """
    Create metallic beveled text with gold/silver appearance
    Perfect for premium UI elements, titles, and special text
    """
    function create_metallic_beveled_text(position::Math.Vector2, text::String, base_color::NTuple{4, Int}=(255, 215, 0, 255))
        # Create base text element
        text_element = UI.create_textbox(text, position=position, color=base_color)
        
        # Configure metallic bevel parameters using BevelEffect1
        bevel_effect = BevelEffect1(
            bevel_type=COMBINED_BEVEL,    # Both inner and outer for metallic look
            bevel_depth=4.0f0,           # More pronounced for metallic effect
            bevel_width=2.5f0,            # Wider bevel for metallic appearance
            light_position=Math.Vector2(0.7, -0.7),  # Angled lighting
            blur_radius=2.0f0,            # Moderate blur for smooth gradients
            intensity=0.9f0,               # High intensity for metallic shine
            
            # Metallic gold gradient
            outer_gradient=[
                GradientStop(0.0f0, (255, 255, 200, 255)),  # Bright gold highlight
                GradientStop(0.3f0, (255, 215, 0, 240)),     # Pure gold
                GradientStop(0.7f0, (218, 165, 32, 220)),    # Darker gold
                GradientStop(1.0f0, (184, 134, 11, 200))     # Deep gold shadow
            ],
            
            # Inner bevel for metallic depth
            inner_gradient=[
                GradientStop(0.0f0, (255, 255, 150, 180)),
                GradientStop(1.0f0, (139, 119, 19, 160))
            ],
            
            # Rich shadow for metallic depth
            shadow_gradient=[
                GradientStop(0.0f0, (139, 119, 19, 120)),
                GradientStop(1.0f0, (101, 67, 33, 100))
            ]
        )
        
        # Apply the metallic beveled text effect using standard effects system
        apply_effects!(text_element, [bevel_effect])
        
        return text_element
    end
    
    """
    Create soft beveled text with gentle gradients
    Ideal for elegant interfaces, menus, and refined UI elements
    """
    function create_soft_beveled_text(position::Math.Vector2, text::String, color::NTuple{4, Int}=(200, 200, 220, 255))
        # Create base text element
        text_element = UI.create_textbox(text, position=position, color=color)
        
        # Configure soft bevel parameters
        beveled_text = BeveledText(
            bevel_type=OUTER_BEVEL,
            bevel_depth=3.0f0,            # Moderate depth
            bevel_width=2.0f0,            # Medium width for soft appearance
            light_position=Math.Vector2(0.8, -0.6),  # Gentle lighting angle
            blur_radius=3.0f0,            # Higher blur for soft edges
            intensity=0.7f0,               # Moderate intensity for elegance
            
            # Soft gradient with gentle transitions
            outer_gradient=[
                GradientStop(0.0f0, (255, 255, 255, 180)),  # Soft white highlight
                GradientStop(0.4f0, (240, 240, 250, 160)),  # Light lavender
                GradientStop(0.8f0, (200, 200, 220, 140)),   # Base color
                GradientStop(1.0f0, (160, 160, 180, 120))    # Soft shadow
            ],
            
            # Gentle shadow gradient
            shadow_gradient=[
                GradientStop(0.0f0, (140, 140, 160, 80)),
                GradientStop(1.0f0, (100, 100, 120, 60))
            ]
        )
        
        # Apply the soft beveled text effect
        apply_beveled_text_effect!(text_element, beveled_text)
        
        return text_element
    end
    
    """
    Create sharp embossed text for technical interfaces
    Provides crisp, defined edges suitable for technical UI elements
    """
    function create_sharp_embossed_text(position::Math.Vector2, text::String, color::NTuple{4, Int}=(150, 150, 150, 255))
        # Create base text element
        text_element = UI.create_textbox(text, position=position, color=color)
        
        # Configure sharp emboss parameters
        beveled_text = BeveledText(
            bevel_type=INNER_BEVEL,       # Inner bevel for embossed look
            bevel_depth=2.0f0,            # Shallow depth for sharp edges
            bevel_width=1.0f0,            # Narrow width for crisp appearance
            light_position=Math.Vector2(1.0, -1.0),  # Direct lighting
            blur_radius=0.5f0,             # Minimal blur for sharp edges
            intensity=0.8f0,               # High intensity for crisp effect
            
            # Sharp gradient with high contrast
            inner_gradient=[
                GradientStop(0.0f0, (255, 255, 255, 220)),  # Bright highlight
                GradientStop(0.5f0, (200, 200, 200, 180)),   # Mid-tone
                GradientStop(1.0f0, (100, 100, 100, 140))   # Dark shadow
            ],
            
            # Strong shadow for embossed effect
            shadow_gradient=[
                GradientStop(0.0f0, (80, 80, 80, 120)),
                GradientStop(1.0f0, (40, 40, 40, 100))
            ]
        )
        
        # Apply the sharp embossed text effect
        apply_beveled_text_effect!(text_element, beveled_text)
        
        return text_element
    end
    
    """
    Apply beveled text effect to a text element using the new system
    This function integrates the new beveled text system with existing UI elements
    """
    # function apply_beveled_text_effect!(text_element, beveled_text::BeveledText)
    #     # Convert text element to surface for processing
    #     if hasfield(typeof(text_element), :image) && text_element.image != nothing
    #         # Get the text surface
    #         text_surface = text_element.image.surface
    #         if text_surface != C_NULL
    #             # Apply the beveled text effect
    #             beveled_surface = apply_bevel_effect_1(text_surface, beveled_text)
    #             if beveled_surface != C_NULL
    #                 # Update the text element's surface
    #                 text_element.image.surface = beveled_surface
                    
    #                 # Regenerate texture if needed
    #                 if text_element.image.texture != C_NULL
    #                     SDL2.SDL_DestroyTexture(text_element.image.texture)
    #                 end
    #                 text_element.image.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, beveled_surface)
    #             end
    #         end
    #     end
    # end
    
    """
    Create a comprehensive demonstration of beveled text effects
    Shows various parameter combinations and their visual results
    """
    # function create_beveled_text_demonstration()
    #     demonstrations = []
        
    #     # Demonstration 1: Parameter sensitivity
    #     # Shows how different blur radius values affect the appearance
    #     blur_values = [0.5f0, 1.5f0, 3.0f0, 5.0f0]
    #     for (i, blur) in enumerate(blur_values)
    #         text = UI.create_textbox("BLUR: $(blur)", position=Math.Vector2(50, 50 + i * 30), color=(255, 255, 255, 255))
    #         beveled_text = BeveledText(blur_radius=blur, intensity=0.8f0)
    #         apply_beveled_text_effect!(text, beveled_text)
    #         push!(demonstrations, ("Blur Radius $(blur)", text))
    #     end
        
    #     # Demonstration 2: Light position effects
    #     # Shows how light position affects the bevel appearance
    #     light_positions = [
    #         Math.Vector2(1.0, -1.0),   # Top-right
    #         Math.Vector2(0.0, -1.0),   # Top
    #         Math.Vector2(-1.0, -1.0),  # Top-left
    #         Math.Vector2(1.0, 0.0),    # Right
    #     ]
    #     for (i, light_pos) in enumerate(light_positions)
    #         text = UI.create_textbox("LIGHT $(i+1)", position=Math.Vector2(200, 50 + i * 30), color=(255, 255, 255, 255))
    #         beveled_text = BeveledText(light_position=light_pos, intensity=0.8f0)
    #         apply_beveled_text_effect!(text, beveled_text)
    #         push!(demonstrations, ("Light Position $(i+1)", text))
    #     end
        
    #     # Demonstration 3: Intensity variations
    #     # Shows how intensity affects the overall effect strength
    #     intensities = [0.3f0, 0.5f0, 0.7f0, 0.9f0]
    #     for (i, intensity) in enumerate(intensities)
    #         text = UI.create_textbox("INTENSITY: $(intensity)", position=Math.Vector2(350, 50 + i * 30), color=(255, 255, 255, 255))
    #         beveled_text = BeveledText(intensity=intensity)
    #         apply_beveled_text_effect!(text, beveled_text)
    #         push!(demonstrations, ("Intensity $(intensity)", text))
    #     end
        
    #     return demonstrations
    # end
    
    """
    Create a simple beveled text that works exactly like the existing effects
    This is the easiest way to use the new BevelEffect1 system
    """
    function create_simple_beveled_text(position::Math.Vector2, text::String, color::NTuple{4, Int}=(255, 255, 255, 255))
        # Create base text element
        text_element = UI.create_textbox(text, position=position, color=color)
        
        # Create a simple bevel effect - works just like other effects!
        bevel_effect = BevelEffect1(
            bevel_type=OUTER_BEVEL,
            bevel_depth=3.0f0,
            light_position=Math.Vector2(1.0, -1.0),
            blur_radius=2.0f0,
            intensity=0.8f0
        )
        
        # Apply it just like any other effect
        apply_effects!(text_element, [bevel_effect])
        
        return text_element
    end
    
    """
    Example usage in CharacterSelection.jl style:
    
    # Simple usage
    local tb_title = JulGame.ImmediateUIModule.immediate_text(
        "title",
        "My Title";
        fontSize = 32,
        anchor = :center,
        color = (255, 255, 255, 255)
    )
    
    # Apply new bevel effect just like other effects
    JulGame.apply_effects!(tb_title, [
        BevelEffect1(
            bevel_type=OUTER_BEVEL,
            bevel_depth=3.0f0,
            light_position=Math.Vector2(1.0, -1.0),
            blur_radius=2.0f0,
            intensity=0.8f0
        )
    ])
    
    # Or combine with other effects
    JulGame.apply_effects!(tb_title, [
        BevelEffect1(bevel_type=OUTER_BEVEL, bevel_depth=3.0f0),
        StrokeEffect(width=2, color=(0,0,0,255)),
        OuterGlowEffect(radius=4, color=(100,100,120,100))
    ])
    """
end
