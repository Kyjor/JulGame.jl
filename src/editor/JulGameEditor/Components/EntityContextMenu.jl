using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
show_entity_context_menu_inspector(currentEntitySelected)
Show menu that allows user to add new components to an entity
"""
function show_entity_context_menu_inspector(currentEntitySelected)
    if CImGui.BeginPopup("##entity_context_menu_inspector")
        if CImGui.MenuItem("Animator")
            JulGame.add_animator(currentEntitySelected)
        end
        if CImGui.MenuItem("Collider")
            JulGame.add_collider(currentEntitySelected)
        end
        if CImGui.MenuItem("Rigidbody")
            JulGame.add_rigidbody(currentEntitySelected)
        end
        if CImGui.MenuItem("Shape")
            JulGame.add_shape(currentEntitySelected)
        end
        if CImGui.MenuItem("SoundSource")
            JulGame.add_sound_source(currentEntitySelected)
        end
        if CImGui.MenuItem("Sprite")
            JulGame.add_sprite(currentEntitySelected, true)
        end
        
        # Close on escape or click outside
        if CImGui.IsKeyPressed(CImGui.ImGuiKey_Escape)
            CImGui.CloseCurrentPopup()
        end
        
        CImGui.EndPopup()
    end
end