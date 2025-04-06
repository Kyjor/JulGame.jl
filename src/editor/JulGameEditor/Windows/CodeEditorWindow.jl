using CImGui
using CImGui: ImVec2
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

# Import the TextEditor from our Components
include(joinpath(@__DIR__, "..", "Components", "TextEditor", "TextEditor.jl"))

mutable struct CodeEditorWindow
    is_open::Bool
    current_file::String
    editor::TextEditor
    language#TODO: correct type::LanguageDefinitionId
    has_unsaved_changes::Bool
    
    function CodeEditorWindow()
        editor = TextEditor()
        setLanguageDefinition(editor, Julia)
        setPalette(editor, Mariana)
        return new(false, "", editor, Julia, false)
    end
end

function open_file(editor_window::CodeEditorWindow, file_path::String)
    if isfile(file_path)
        # Read the file content
        content = read(file_path, String)
        
        # Set the content to the editor
        setText(editor_window.editor, content)
        
        # Update the current file path
        editor_window.current_file = file_path
        
        # Set the language based on file extension
        ext = lowercase(splitext(file_path)[2])
        if ext == ".jl"
            setLanguageDefinition(editor_window.editor, Julia)
            editor_window.language = Julia
        elseif ext == ".cpp" || ext == ".h" || ext == ".hpp"
            setLanguageDefinition(editor_window.editor, Cpp)
            editor_window.language = Cpp
        elseif ext == ".c"
            setLanguageDefinition(editor_window.editor, C)
            editor_window.language = C
        elseif ext == ".py"
            setLanguageDefinition(editor_window.editor, Python)
            editor_window.language = Python
        elseif ext == ".json"
            setLanguageDefinition(editor_window.editor, Json)
            editor_window.language = Json
        elseif ext == ".lua"
            setLanguageDefinition(editor_window.editor, Lua)
            editor_window.language = Lua
        end
        
        # Reset unsaved changes flag
        editor_window.has_unsaved_changes = false
        
        # Open the window
        editor_window.is_open = true
        
        return true
    end
    
    return false
end

function save_file(editor_window::CodeEditorWindow)
    if editor_window.current_file != ""
        # Get content from editor
        content = getText(editor_window.editor)
        
        # Write to file
        open(editor_window.current_file, "w") do file
            write(file, content)
        end
        
        # Reset unsaved changes flag
        editor_window.has_unsaved_changes = false
        
        return true
    end
    
    return false
end

function save_file_as(editor_window::CodeEditorWindow, file_path::String)
    # Update the current file path
    editor_window.current_file = file_path
    
    # Save to the new path
    return save_file(editor_window)
end

function show(editor_window::CodeEditorWindow)
    @cstatic begin
        if !editor_window.is_open
            return
        end
        
        # Create window title with file name
        file_name = basename(editor_window.current_file)
        title = editor_window.has_unsaved_changes ? "$(file_name)*###CodeEditor" : "$(file_name)###CodeEditor"
        
        # Begin window
        is_open = Ref(editor_window.is_open)
        CImGui.Begin(title, is_open, CImGui.ImGuiWindowFlags_MenuBar)
        editor_window.is_open = is_open[]
        
        # Menu bar
        if CImGui.BeginMenuBar()
            if CImGui.BeginMenu("File")
                if CImGui.MenuItem("Save", "Ctrl+S")
                    save_file(editor_window)
                end
                
                if CImGui.MenuItem("Save As...", "Ctrl+Shift+S")
                    # Open a dialog to get the save path (you'll need to implement this)
                    # For now, just save to the current file
                    save_file(editor_window)
                end
                
                if CImGui.MenuItem("Close", "Ctrl+W")
                    if !editor_window.has_unsaved_changes
                        editor_window.is_open = false
                    else
                        # TODO: Prompt for save
                        editor_window.is_open = false
                    end
                end
                
                CImGui.EndMenu()
            end
            
            if CImGui.BeginMenu("Edit")
                # Undo and Redo
                if CImGui.MenuItem("Undo", "Ctrl+Z", false, canUndo(editor_window.editor))
                    undo(editor_window.editor)
                end
                
                if CImGui.MenuItem("Redo", "Ctrl+Y", false, canRedo(editor_window.editor))
                    redo(editor_window.editor)
                end
                
                CImGui.Separator()
                
                # Cut, Copy, Paste
                if CImGui.MenuItem("Cut", "Ctrl+X")
                    cut(editor_window.editor)
                end
                
                if CImGui.MenuItem("Copy", "Ctrl+C")
                    copy(editor_window.editor)
                end
                
                if CImGui.MenuItem("Paste", "Ctrl+V")
                    paste(editor_window.editor)
                end
                
                CImGui.Separator()
                
                # Select All
                if CImGui.MenuItem("Select All", "Ctrl+A")
                    selectAll(editor_window.editor)
                end
                
                CImGui.EndMenu()
            end
            
            if CImGui.BeginMenu("View")
                # Dark theme
                if CImGui.MenuItem("Dark Theme", nothing, editor_window.editor.paletteId == Dark)
                    setPalette(editor_window.editor, Dark)
                end
                
                # Light theme
                if CImGui.MenuItem("Light Theme", nothing, editor_window.editor.paletteId == Light)
                    setPalette(editor_window.editor, Light)
                end
                
                # Retro Blue theme
                if CImGui.MenuItem("RetroBlue Theme", nothing, editor_window.editor.paletteId == RetroBlue)
                    setPalette(editor_window.editor, RetroBlue)
                end
                
                # Mariana theme
                if CImGui.MenuItem("Mariana Theme", nothing, editor_window.editor.paletteId == Mariana)
                    setPalette(editor_window.editor, Mariana)
                end
                
                CImGui.Separator()
                
                # Show line numbers
                show_line_numbers = Ref(isShowLineNumbersEnabled(editor_window.editor))
                if CImGui.MenuItem("Show Line Numbers", nothing, show_line_numbers)
                    setShowLineNumbersEnabled(editor_window.editor, show_line_numbers[])
                end
                
                # Show whitespace
                show_whitespace = Ref(isShowWhitespacesEnabled(editor_window.editor))
                if CImGui.MenuItem("Show Whitespace", nothing, show_whitespace)
                    setShowWhitespacesEnabled(editor_window.editor, show_whitespace[])
                end
                
                CImGui.EndMenu()
            end
            
            CImGui.EndMenuBar()
        end
        
        # File content display area
        content_available_width = CImGui.GetContentRegionAvail().x
        content_available_height = CImGui.GetContentRegionAvail().y
        
        # Render the editor
        if render(editor_window.editor, "Editor", true, ImVec2(content_available_width, content_available_height))
            # Editor content changed
            editor_window.has_unsaved_changes = true
        end
        
        CImGui.End()
    end
end 