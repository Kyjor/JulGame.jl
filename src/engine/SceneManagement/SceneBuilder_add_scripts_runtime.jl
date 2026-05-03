function add_scripts_to_entities(path::String)
    JulGame.juliac_trim_active() && return nothing
    @debug string("Adding scripts to entities")
    @debug string("Path: ", path)
    main_loop = JulGame.current_main()
    entities = main_loop.scene.entities::Vector{Entity}
    @debug string("Entities: ", length(entities))
    loaded_scripts::Set{String} = JulGame.LoadedScripts

    if !JulGame.IS_PACKAGE_COMPILED
        @debug "Package not compiled, skipping dynamic script includes in trim-safe path"
    end

    project_module_value = JulGame.ProjectModule
    project_module_name = project_module_value isa String ? project_module_value : ""
    if !isempty(project_module_name)
        @debug "Loading scripts from project module: $(project_module_name)"
        project_module_symbol = Symbol(project_module_name)
        if isdefined(Main, project_module_symbol)
            project_module = getfield(Main, project_module_symbol)
            if isdefined(project_module, :Scripts)
                JulGame.ScriptModule = getfield(project_module, :Scripts)
            end
        end
    end

    for entity in entities
        scriptCounter = 1
        for script in entity.scripts
            if !isa(script, JSON3.Object)
                scriptCounter += 1
                continue
            end
            script_obj = script::JSON3.Object
            script_name = _json3_string(script_obj, :name, "")
            isempty(script_name) && (scriptCounter += 1; continue)
            @debug String("Adding script: $(script_name) to entity: $(entity.name)")

            newScript = nothing
            try
                script_module = JulGame.ScriptModule
                script_module isa Module || continue
                module_name = getfield(script_module, Symbol("$(script_name)Module"))
                constructor = Base.invokelatest(getfield, module_name, Symbol(script_name))
                newScript = Base.invokelatest(constructor)
                scriptFields = _json3_fields(script_obj)
                @debug("getting fields for: $(script_obj)")
                if newScript !== nothing
                    scriptFields_obj::JSON3.Object = scriptFields
                    for key_symbol in keys(scriptFields_obj)
                        value = get(scriptFields_obj, key_symbol, nothing)
                        try
                            ftype = fieldtype(typeof(newScript), key_symbol)
                            @debug("type: $(ftype)")
                            if ftype <: EditorExport
                                @debug "Overwriting $(key_symbol) to $(value) using scene file"
                                underlying_type = ftype.parameters[1]
                                Base.invokelatest(setfield!, newScript, key_symbol, EditorExport(convert(underlying_type, value)))
                                continue
                            elseif value === nothing
                                @debug "Value is nothing"
                                continue
                            end
                        catch e
                            @warn string(e)
                        end
                    end
                end
            catch e
                @error sprint(showerror, e)
            end
            if newScript !== nothing
                entity.scripts[scriptCounter] = newScript
            end
            scriptCounter += 1
        end
    end
    return nothing
end
