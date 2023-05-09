using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
ShowEntityContextMenu()
Create a fullscreen menu bar and populate it.
"""
function ShowEntityContextMenu(currentEntitySelected)
    CImGui.MenuItem("Entity Menu", C_NULL, false, false)
    if CImGui.BeginMenu("New Component")
        if CImGui.MenuItem("Animator")
            
        end
        if CImGui.MenuItem("Collider")
            currentEntitySelected.addCollider()
        end
        if CImGui.MenuItem("Rigidbody")
            @info "Replace me"
        end
        if CImGui.MenuItem("SoundSource")
            @info "Replace me"
        end
        if CImGui.MenuItem("Sprite")
            @info "Replace me"
        end
        if CImGui.MenuItem("Transform")
            @info "Replace me"
        end
        
        CImGui.EndMenu()
    end
end