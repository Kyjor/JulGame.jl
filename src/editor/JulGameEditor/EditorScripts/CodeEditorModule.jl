module CodeEditorModule

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using NativeFileDialog
using JulGame

include(joinpath(@__DIR__, "..", "Windows", "CodeEditorWindow.jl"))

# Global code editor instance
const CODE_EDITOR = CodeEditorWindow()

"""
Show the code editor window. Call this function from the main editor loop.
"""
function show_code_editor()
    show(CODE_EDITOR)
end

"""
Open a file in the code editor. Returns true if the file was successfully opened.
"""
function open_file_in_editor(file_path::String)
    return open_file(CODE_EDITOR, file_path)
end

"""
Show a file open dialog and open the selected file in the code editor.
"""
function open_file_dialog()
    # Show the file open dialog
    filters = "jl"
    path = pick_file(JulGame.BasePath; filterlist=filters)
    
    if path !== nothing && isfile(path)
        return open_file_in_editor(path)
    end
    
    return false
end

"""
Save the current file in the code editor. Returns true if the file was successfully saved.
"""
function save_current_file()
    return save_file(CODE_EDITOR)
end

"""
Show a file save dialog and save the current file in the code editor.
"""
function save_file_as_dialog()
    # Show the file save dialog
    filters = "jl,c,cpp,h,hpp"
    path = pick_file(JulGame.BasePath; filterlist=filters)
    
    if path !== nothing
        return save_file_as(CODE_EDITOR, path)
    end
    
    return false
end

end # module 