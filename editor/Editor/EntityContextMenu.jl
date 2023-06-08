using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
ShowEntityContextMenu()
Show menu that allows user to add new components to an entity
"""
function ShowEntityContextMenu(basePath, currentEntitySelected, game)
    CImGui.MenuItem("Entity Menu", C_NULL, false, false)
    if CImGui.BeginMenu("New Component")
        if CImGui.MenuItem("Animator")
            currentEntitySelected.addAnimator()
        end
        if CImGui.MenuItem("Collider")
            currentEntitySelected.addCollider()
        end
        if CImGui.MenuItem("Rigidbody")
            currentEntitySelected.addRigidbody()
        end
        if CImGui.MenuItem("SoundSource")
            currentEntitySelected.addSoundSource()
        end
        if CImGui.MenuItem("Sprite")
            currentEntitySelected.addSprite(basePath, game)
        end
        
        CImGui.EndMenu()
    end
end