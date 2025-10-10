using CImGui
using JulGame

function display_script_field_input(script, field)
    ftype = typeof(getproperty(script, field))
    if ftype == String
        buf = "$(getproperty(script, field))"*"\0"^(64)
        CImGui.InputText("$(field)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setproperty!(script, field, currentTextInTextBox)
    elseif ftype == Float64 || ftype == Float32
        x = ftype(getproperty(script, field))
        x = Cfloat(x)
        @c CImGui.InputFloat("$(field)", &x, 1)
        setproperty!(script, field, ftype(x))
    elseif ftype <: Int64 || ftype <: Int32 || ftype <: Int16 || ftype <: Int8
        x = ftype(getproperty(script, field))
        x = convert(Int32, x)
        @c CImGui.InputInt("$(field)", &x, 1)
        x = convert(ftype, x)
        setproperty!(script, field, x)
    elseif ftype == Bool
        x = getproperty(script, field)
        @c CImGui.Checkbox("$(field)", &x)
        setproperty!(script, field, x)
    end
end

function init_undefined_field(script, field)
    ftype = typeof(getproperty(script, field))
    if ftype == String
        setproperty!(script, field, "")
    elseif ftype <: Number
        setproperty!(script, field, 0)
    elseif ftype == Bool
        setproperty!(script, field, false)
    end
end

"""
    open_file_in_editor(file_path::String)

Opens a file in the user's preferred editor. Falls back to system default if no preference is set.
Supports configuration via config.julgame file with "PreferredEditor" setting.

Supported editors:
- "vscode" - Visual Studio Code
- "sublime" - Sublime Text  
- "atom" - Atom Editor
- "vim" - Vim/NeoVim
- "emacs" - Emacs
- "nano" - Nano
- "system" - Use system default file association
- "custom" - Use custom command from "CustomEditorCommand" config
"""
function open_file_in_editor(file_path::String)
    # Get editor preference from config
    editor_preference = get_editor_preference()
    
    try
        if editor_preference == "vscode"
            open_in_vscode(file_path)
        elseif editor_preference == "sublime"
            open_in_sublime(file_path)
        elseif editor_preference == "atom"
            open_in_atom(file_path)
        elseif editor_preference == "vim"
            open_in_vim(file_path)
        elseif editor_preference == "emacs"
            open_in_emacs(file_path)
        elseif editor_preference == "nano"
            open_in_nano(file_path)
        elseif editor_preference == "custom"
            open_in_custom_editor(file_path)
        else
            # Default: use system file association
            open_with_system_default(file_path)
        end
    catch e
        @warn "Failed to open file with preferred editor ($editor_preference): $e"
        @info "Falling back to system default"
        try
            open_with_system_default(file_path)
        catch fallback_error
            @error "Failed to open file with system default: $fallback_error"
        end
    end
end

function get_editor_preference()
    # Try to read from project config first
    try
        config_path = joinpath(JulGame.BasePath, "config.julgame")
        if isfile(config_path)
            config = Dict{String, String}()
            open(config_path, "r") do file
                for line in eachline(file)
                    if contains(line, "=")
                        key, value = split(line, "=", limit=2)
                        config[strip(key)] = strip(value)
                    end
                end
            end
            return get(config, "PreferredEditor", "system")
        end
    catch e
        @debug "Could not read editor preference from config: $e"
    end
    
    return "system"  # Default fallback
end

function open_with_system_default(file_path::String)
    if Sys.iswindows()
        run(`cmd /c start "" "$file_path"`)
    elseif Sys.isapple()
        run(`open "$file_path"`)
    else  # Linux and other Unix-like systems
        run(`xdg-open "$file_path"`)
    end
end

function open_in_vscode(file_path::String)
    # Try VSCode URL scheme first (works if VSCode is running)
    try
        SDL2.SDL_OpenURL("vscode://file/$(file_path)")
        return
    catch
        # Fall back to command line
        if Sys.iswindows()
            run(`code "$file_path"`)
        else
            run(`code "$file_path"`)
        end
    end
end

function open_in_sublime(file_path::String)
    if Sys.iswindows()
        run(`subl "$file_path"`)
    elseif Sys.isapple()
        run(`subl "$file_path"`)
    else
        run(`subl "$file_path"`)
    end
end

function open_in_atom(file_path::String)
    run(`atom "$file_path"`)
end

function open_in_vim(file_path::String)
    if Sys.iswindows()
        # Open in new terminal window
        run(`cmd /c start cmd /k "vim \"$file_path\""`)
    else
        # Try to detect terminal and open vim
        terminals = ["gnome-terminal", "konsole", "xterm", "alacritty", "kitty"]
        for terminal in terminals
            try
                if terminal == "gnome-terminal"
                    run(`$terminal -- vim "$file_path"`)
                elseif terminal == "konsole"
                    run(`$terminal -e vim "$file_path"`)
                else
                    run(`$terminal -e vim "$file_path"`)
                end
                return
            catch
                continue
            end
        end
        # Fallback: try vim in current terminal (won't work in GUI context)
        run(`vim "$file_path"`)
    end
end

function open_in_emacs(file_path::String)
    run(`emacs "$file_path"`)
end

function open_in_nano(file_path::String)
    if Sys.iswindows()
        run(`cmd /c start cmd /k "nano \"$file_path\""`)
    else
        terminals = ["gnome-terminal", "konsole", "xterm"]
        for terminal in terminals
            try
                run(`$terminal -e nano "$file_path"`)
                return
            catch
                continue
            end
        end
        run(`nano "$file_path"`)
    end
end

function open_in_custom_editor(file_path::String)
    # Get custom command from config
    try
        config_path = joinpath(JulGame.BasePath, "config.julgame")
        if isfile(config_path)
            config = Dict{String, String}()
            open(config_path, "r") do file
                for line in eachline(file)
                    if contains(line, "=")
                        key, value = split(line, "=", limit=2)
                        config[strip(key)] = strip(value)
                    end
                end
            end
            
            custom_command = get(config, "CustomEditorCommand", "")
            if !isempty(custom_command)
                # Replace {file} placeholder with actual file path
                command = replace(custom_command, "{file}" => file_path)
                run(`$command`)
                return
            end
        end
    catch e
        @error "Failed to execute custom editor command: $e"
    end
    
    throw(ErrorException("No custom editor command configured"))
end


function create_new_script(name)
    path = joinpath(JulGame.BasePath, "scripts", "$(name).jl")
    touch(joinpath(path))
    file = open(path, "w")
        println(file, newScriptContent(name))
    close(file)

    open_file_in_editor(path)
end

function show_script_editor(entity, newScriptText)
    if CImGui.TreeNode("Scripts")
        # Show current scripts count
        CImGui.Text("Scripts: $(length(entity.scripts)) script(s)")
        
        # Add Script button using the file finder modal
        if CImGui.Button("Add Script...")
            open_file_finder_modal(string(joinpath(JulGame.BasePath, "scripts")), "scripts", "Select Script File", :scripts, "Entity")
        end
        
        # Check if a script was selected from the modal
        if !is_file_finder_open() && get_file_finder_result() != ""
            selected_file = get_file_finder_result()
            target_field, target_structure_type = get_file_finder_target()
            
            @info "Script selection result: $selected_file"
            @info "Target field: $target_field, Target structure: $target_structure_type"
            
            # Only apply the result if this is for scripts
            if target_field == :scripts && target_structure_type == "Entity"
                # Extract script name from file path
                script_name = splitext(basename(selected_file))[1]
                @info "Adding script: $script_name to entity: $(entity.name)"
                add_script_to_entity(entity, script_name)
                
                # Clear the result to prevent re-processing
                state = JulGame.EditorState["file_finder"]
                state.selected_file = ""
            end
        end
        
        # Display existing scripts
        for i = eachindex(entity.scripts)
            scriptName = split("$(typeof(entity.scripts[i]))", ".")[end]
            if CImGui.TreeNode("$(i): $(scriptName)")
                if CImGui.Button("Open Script")
                    path = joinpath(JulGame.BasePath, "scripts", "$(scriptName).jl")
                    open_file_in_editor(path)
                end

                if CImGui.Button("Reload $scriptName:$(i)")
                    reload_script(entity, i, scriptName)
                end
                
                if CImGui.Button("Remove Script")
                    deleteat!(entity.scripts, i)
                    CImGui.TreePop()
                    break
                end

                # Show script fields for editing
                for field in fieldnames(typeof(entity.scripts[i]))
                    if field == :parent || !(fieldtype(typeof(entity.scripts[i]), field) <: EditorExport)
                        continue
                    end
                    if isdefined(entity.scripts[i], Symbol(field)) 
                        display_script_field_input(entity.scripts[i], field)
                    else 
                        init_undefined_field(entity.scripts[i], field)
                    end
                end

                CImGui.TreePop()
            end
        end
        CImGui.TreePop()
    end
end

function add_script_to_entity(entity, script_name)
    @debug("Adding script: $(script_name) to: $(entity.name)")
    try
        script_path = joinpath(JulGame.BasePath, "scripts", "$(script_name).jl")
        Base.include(JulGame.ScriptModule, script_path)
        module_name = getfield(JulGame.ScriptModule, Symbol("$(script_name)Module"))
        constructor = Base.invokelatest(getfield, module_name, Symbol(script_name)) 
        newScript = Base.invokelatest(constructor)
        newScript.parent = entity
        push!(entity.scripts, newScript)
        @info "Successfully added script: $script_name to entity: $(entity.name)"
    catch e
        @error "Failed to add script $script_name: $e"
        Base.show_backtrace(stderr, catch_backtrace())
    end
end

function reload_script(entity, script_index, script_name)
    try
        script_path = joinpath(JulGame.BasePath, "scripts", "$(script_name).jl")
        Base.include(JulGame.ScriptModule, script_path)
        module_name = getfield(JulGame.ScriptModule, Symbol("$(script_name)Module"))
        constructor = Base.invokelatest(getfield, module_name, Symbol(script_name)) 
        entity.scripts[script_index] = Base.invokelatest(constructor)
        entity.scripts[script_index].parent = entity
        @info "Successfully reloaded script: $script_name"
    catch e
        @error "Failed to reload script $script_name: $e"
        Base.show_backtrace(stderr, catch_backtrace())
    end
end