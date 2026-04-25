# TextBox effects stack: add combo, ordered list with remove, dispatch to panels.

const _TEXT_FX_ADD_IX = Ref(Int32(0))

_fx_qstr(s::AbstractString) = "\"" * replace(String(s), "\\" => "\\\\", "\"" => "\\\"") * "\""
_fx_tuple4(t) = "($(Int(t[1])), $(Int(t[2])), $(Int(t[3])), $(Int(t[4])))"
_fx_vec_tuple4(v) = "[" * join(["($(p), $(_fx_tuple4(c)))" for (p, c) in v], ", ") * "]"
_fx_lut_code(lut::Vector{UInt8}) = lut == JulGame.EffectsModule.identity_emboss_lut() ? "JulGame.EffectsModule.identity_emboss_lut()" : "UInt8[" * join(string.(Int.(lut)), ", ") * "]"

function _fx_gradient_stop_vec_code(v::Vector{JulGame.EffectsModule.GradientStop})
    items = String[]
    for s in v
        push!(items, "JulGame.EffectsModule.GradientStop($(Float32(s.position))f0, (UInt8($(Int(s.color[1]))), UInt8($(Int(s.color[2]))), UInt8($(Int(s.color[3]))), UInt8($(Int(s.color[4])))))")
    end
    return "[" * join(items, ", ") * "]"
end

function _fx_effect_code(eff)::String
    EM = JulGame.EffectsModule
    if eff isa EM.BevelEmbossEffect
        return "JulGame.EffectsModule.BevelEmbossEffect(; style=$(string(eff.style)), size_px=$(eff.size_px), soften=$(Float32(eff.soften))f0, depth=$(eff.depth), angle=$(eff.angle), altitude=$(eff.altitude), direction_up=$(eff.direction_up), contour_enabled=$(eff.contour_enabled), range_pct=$(eff.range_pct), contour_lut=$(_fx_lut_code(eff.contour_lut)), contour_antialiased=$(eff.contour_antialiased), gloss_enabled=$(eff.gloss_enabled), gloss_lut=$(_fx_lut_code(eff.gloss_lut)), gloss_antialiased=$(eff.gloss_antialiased), texture_enabled=$(eff.texture_enabled), texture_path=$(_fx_qstr(eff.texture_path)), texture_tile=$(eff.texture_tile), texture_scale=$(eff.texture_scale), texture_phase_h_pct=$(eff.texture_phase_h_pct), texture_phase_v_pct=$(eff.texture_phase_v_pct), texture_align_with_layer=$(eff.texture_align_with_layer), texture_depth=$(eff.texture_depth), texture_invert=$(eff.texture_invert), highlight_color=$(_fx_tuple4(eff.highlight_color)), shadow_color=$(_fx_tuple4(eff.shadow_color)), highlight_opacity=$(eff.highlight_opacity), shadow_opacity=$(eff.shadow_opacity), highlight_blend=$(string(eff.highlight_blend)), shadow_blend=$(string(eff.shadow_blend)), intensity=$(eff.intensity))"
    elseif eff isa EM.DropShadowEffect
        return "JulGame.EffectsModule.DropShadowEffect(; distance=$(eff.distance), angle=$(eff.angle), blur_radius=$(eff.blur_radius), color=$(_fx_tuple4(eff.color)), opacity=$(eff.opacity))"
    elseif eff isa EM.OuterGlowEffect
        return "JulGame.EffectsModule.OuterGlowEffect(; radius=$(eff.radius), color=$(_fx_tuple4(eff.color)), blur=$(eff.blur), force_white=$(eff.force_white), fade_amount=$(eff.fade_amount), fade_curve=$(eff.fade_curve))"
    elseif eff isa EM.InnerGlowEffect
        return "JulGame.EffectsModule.InnerGlowEffect(; radius=$(eff.radius), color=$(_fx_tuple4(eff.color)))"
    elseif eff isa EM.StrokeEffect
        return "JulGame.EffectsModule.StrokeEffect(; width=$(eff.width), color=$(_fx_tuple4(eff.color)))"
    elseif eff isa EM.RoughEdgeEffect
        return "JulGame.EffectsModule.RoughEdgeEffect(; amount=$(eff.amount), seed=$(eff.seed), erosion=$(eff.erosion))"
    elseif eff isa EM.InvertEffect
        return "JulGame.EffectsModule.InvertEffect(; invert_red=$(eff.invert_red), invert_green=$(eff.invert_green), invert_blue=$(eff.invert_blue), invert_alpha=$(eff.invert_alpha))"
    elseif eff isa EM.BevelEffect
        return "JulGame.EffectsModule.BevelEffect(; depth=$(eff.depth), angle=$(eff.angle), highlight_color=$(_fx_tuple4(eff.highlight_color)), shadow_color=$(_fx_tuple4(eff.shadow_color)), intensity=$(eff.intensity))"
    elseif eff isa EM.TextureFillEffect
        return "JulGame.EffectsModule.TextureFillEffect(; texturePath=$(_fx_qstr(eff.texturePath)), tile=$(eff.tile), blendMode=$(eff.blendMode), opacity=$(eff.opacity))"
    elseif eff isa EM.GradientEffect
        return "JulGame.EffectsModule.GradientEffect(; gradientType=$(_fx_qstr(eff.gradientType)), stops=$(_fx_vec_tuple4(eff.stops)), angle=$(eff.angle))"
    elseif eff isa EM.BevelEffect1
        return "JulGame.EffectsModule.BevelEffect1(; bevel_type=$(string(eff.bevel_type)), bevel_depth=$(Float32(eff.bevel_depth))f0, bevel_width=$(Float32(eff.bevel_width))f0, light_position=JulGame.Math.Vector2($(eff.light_position.x), $(eff.light_position.y)), blur_radius=$(Float32(eff.blur_radius))f0, intensity=$(Float32(eff.intensity))f0, inner_gradient=$(_fx_gradient_stop_vec_code(eff.inner_gradient)), outer_gradient=$(_fx_gradient_stop_vec_code(eff.outer_gradient)), shadow_gradient=$(_fx_gradient_stop_vec_code(eff.shadow_gradient)))"
    end
    return "# Unsupported effect: $(nameof(typeof(eff)))"
end

function _fx_effects_stack_code(target)::String
    items = [_fx_effect_code(eff) for eff in target.effects]
    body = join(["    " * i for i in items], ",\n")
    return "JulGame.apply_effects!(target, Any[\n" * body * "\n])"
end

function _text_fx_push_new!(target, ix0::Int)
    EM = JulGame.EffectsModule
    e = if ix0 == 0
        EM.BevelEmbossEffect()
    elseif ix0 == 1
        EM.DropShadowEffect()
    elseif ix0 == 2
        EM.OuterGlowEffect()
    elseif ix0 == 3
        EM.InnerGlowEffect()
    elseif ix0 == 4
        EM.StrokeEffect()
    elseif ix0 == 5
        EM.RoughEdgeEffect()
    elseif ix0 == 6
        EM.InvertEffect()
    elseif ix0 == 7
        EM.BevelEffect()
    elseif ix0 == 8
        EM.GradientEffect(; stops = [(0.0, (255, 255, 255, 255)), (1.0, (0, 0, 0, 255))])
    elseif ix0 == 9
        EM.TextureFillEffect()
    elseif ix0 == 10
        EM.BevelEffect1()
    else
        return
    end
    push!(target.effects, e)
    JulGame.apply_effects!(target, target.effects)
end

function show_text_effects_inspector(target)
    if CImGui.CollapsingHeader("Text effects##text_fx_header", CImGui.ImGuiTreeNodeFlags_DefaultOpen)
        CImGui.Indent(4.0f0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, CImGui.ImVec2(6, 6))

        ADD_LABELS = [
            "Bevel / emboss",
            "Drop shadow",
            "Outer glow",
            "Inner glow",
            "Stroke",
            "Rough edge",
            "Invert",
            "Bevel (legacy)",
            "Gradient",
            "Texture fill",
            "Bevel v1",
        ]
        CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
        @c CImGui.Combo("Add effect##fx_add_combo", _TEXT_FX_ADD_IX, ADD_LABELS, length(ADD_LABELS))
        CImGui.SameLine()
        if CImGui.Button("Add##fx_add_btn")
            _text_fx_push_new!(target, Int(_TEXT_FX_ADD_IX[]))
        end
        CImGui.SameLine()
        if CImGui.Button("Copy as Julia##fx_copy_code")
            CImGui.SetClipboardText(_fx_effects_stack_code(target))
        end

        if isempty(target.effects)
            CImGui.TextWrapped("Stack is empty. Pick an effect above and click Add.")
        end

        for (i, eff) in enumerate(target.effects)
            if CImGui.CollapsingHeader("$(i). $(nameof(typeof(eff)))##fx_row_$i")
                show_effect_panel_for(eff, target)
                if i > 1
                    if CImGui.Button("Move up##fx_up_$i")
                        target.effects[i - 1], target.effects[i] = target.effects[i], target.effects[i - 1]
                        JulGame.apply_effects!(target, target.effects)
                        break
                    end
                    CImGui.SameLine()
                end
                if i < length(target.effects)
                    if CImGui.Button("Move down##fx_down_$i")
                        target.effects[i + 1], target.effects[i] = target.effects[i], target.effects[i + 1]
                        JulGame.apply_effects!(target, target.effects)
                        break
                    end
                    CImGui.SameLine()
                end
                if CImGui.Button("Remove##fx_rm_$i")
                    deleteat!(target.effects, i)
                    JulGame.apply_effects!(target, target.effects)
                    break
                end
            end
        end

        CImGui.PopStyleVar()
        CImGui.Unindent(4.0f0)
    end
end
