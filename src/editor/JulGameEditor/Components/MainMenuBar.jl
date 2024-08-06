using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
    ShowAppMainMenuBar(events)
Create a fullscreen menu bar and populate it.

# Arguments
- `events`: An array of event functions. These are callbacks that are triggered when the user selects a menu item.
"""
function show_main_menu_bar(events)
    if CImGui.BeginMainMenuBar()
        @cstatic buf="File"*"\0"^128 begin
            if CImGui.BeginMenu(buf)
                ShowMenuFile(events)
                CImGui.EndMenu()
            end

            CImGui.EndMainMenuBar()
        end
    end
end

"""
    ShowMenuFile(events)

Show the file menu in the main menu bar.

# Arguments
- `events`: An array of event functions. These are callbacks that are triggered when the user selects a menu item.
"""
function ShowMenuFile(events)
    if CImGui.MenuItem("Open", "Ctrl+O.")
        events[end]()
    end
    if length(events) > 1 && CImGui.MenuItem("Save", "Ctrl+S")
        @info "Trigger Save | find me here: $(@__FILE__):$(@__LINE__)"
        events[1]()
    end
end