EditableComponent = Union{AnimatorModule.InternalAnimator, ColliderModule.InternalCollider, ShapeModule.InternalShape, RigidbodyModule.InternalRigidbody, SoundSourceModule.InternalSoundSource, SpriteModule.InternalSprite, TransformModule.Transform}
EditableStructure = Union{JulGame.CameraModule.Camera, Entity, UI.UIElement, EditableComponent}
include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Fields"); join=true)))
include(joinpath(@__DIR__, "..", "EntityContextMenu.jl"))

function show_inspector(currentSceneMain::Union{MainLoop, Nothing})
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowMinSize, CImGui.ImVec2(0, 0))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, CImGui.ImVec2(0, 0))
    CImGui.Begin("Inspector") 
    if currentSceneMain !== nothing && currentSceneMain.selectedEntities !== nothing && length(currentSceneMain.selectedEntities) == 1
        selectedEntity = currentSceneMain.selectedEntities[1]
        display_context_menu = 0
        if selectedEntity !== nothing
            display_context_menu = display_inspector_header(selectedEntity)
            display_fields(selectedEntity)
        end
        
        # Left-click context menu for adding components
        # Check if left mouse button is clicked in the Inspector window
        if display_context_menu == 1
            @info "Opening entity context menu"
            CImGui.OpenPopup(INSPECTOR_LEFT_CLICK_MENU)
        end
        
        # # Define the popup content
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, CImGui.ImVec2(5, 5))
        if CImGui.BeginPopup(INSPECTOR_LEFT_CLICK_MENU)
            show_entity_context_menu_inspector(selectedEntity)
            CImGui.EndPopup()
        end
        
        CImGui.PopStyleVar()
    elseif currentSceneMain !== nothing && currentSceneMain.selectedEntities !== nothing && length(currentSceneMain.selectedEntities) > 1
        CImGui.Text("Please select only one entity to inspect.")
    end
    CImGui.PopStyleVar(2)
    CImGui.End()
end

function display_inspector_header(structure::EditableStructure)
    display_menu = 0
    #add component, duplicate, delete buttons
    #CImGui.PushStyleVar(CImGui.ImGuiStyleVar_CellPadding, CImGui.ImVec2(100, 100))
    table_flags = CImGui.ImGuiTableFlags_SizingFixedFit | CImGui.ImGuiTableFlags_NoPadOuterX
    # CImGui.SetNextItemWidth(CImGui.GetContentRegionAvail().x)
    available_width = CImGui.GetContentRegionAvail().x
    if CImGui.BeginTable("Inspector Header", 3, table_flags)#, CImGui.ImVec2(available_width, 0))
        CImGui.TableSetupColumn("Add Component",CImGui.ImGuiTableColumnFlags_WidthStretch)
        CImGui.TableSetupColumn("Duplicate",CImGui.ImGuiTableColumnFlags_WidthStretch)
        CImGui.TableSetupColumn("Delete",CImGui.ImGuiTableColumnFlags_WidthStretch)
        CImGui.TableNextRow(CImGui.ImGuiTableRowFlags_Headers)
        column_selected = [false, false, false]
        for column = 0:2
            CImGui.TableSetColumnIndex(column)
            column_name = CImGui.TableGetColumnName(column)
            CImGui.PushID(column)
            # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, CImGui.ImVec2(0, 0))
            # @c CImGui.Checkbox("##checkall", &column_selected[column])
            # CImGui.PopStyleVar()
            CImGui.SameLine(0.0f0, unsafe_load(CImGui.GetStyle().ItemInnerSpacing.x))
            CImGui.TableHeader(column_name)
            if CImGui.IsItemHovered()
                CImGui.BeginTooltip()
                CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
                CImGui.TextUnformatted(ToolTips[Symbol(replace(column_name, " " => ""))])
                CImGui.PopTextWrapPos()
                CImGui.EndTooltip()
            end
            if CImGui.IsItemClicked()
                display_menu = handle_column_click(column_name, structure)
            end
            CImGui.PopID()
        end
               
        CImGui.EndTable()
    end

    return display_menu
end

function handle_column_click(column_name, structure)
    if column_name == "Add Component"
        return 1
    elseif column_name == "Duplicate"
        JulGame.duplicate(structure)
    elseif column_name == "Delete"
        JulGame.EditorState[DELETE_CONFIRMATION] = () -> JulGame.destroy_entity(structure)
        return 2
    end

    return 0
end

function display_fields(structure::EditableStructure)
    CImGui.Indent(8.0f0)  # Left padding
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, CImGui.ImVec2(8, 8))

    fields = [fieldnames(typeof(structure))...]
    if isa(structure, UI.UIElement)
        uiFields = [fieldnames(JulGame.UI.UIElementInstance)...]
        prepend!(fields, uiFields)
    end
    for field in fields
        structureType = split(string(typeof(structure)), ".")[end]
        if (get(FieldExclusions, structureType, []) != [] && field in get(FieldExclusions, structureType, [])) || (isa(structure, UI.UIElement) && field in get(FieldExclusions, "UIElement", [])) && field != :parent
            continue
        end

        customField = get(CustomMappings, structureType, nothing)[field]
        if field == :parent
            show_parent_field(structure, field, getproperty(structure, field))
        elseif get(CustomMappings, structureType, Dict{Symbol, Symbol}())[field] != nothing
        else
            show_field(structure, field, getproperty(structure, field))
        end
    end
    CImGui.Unindent(8.0f0)
    CImGui.PopStyleVar()
end

function display_fields(structure::Any)
    # unmapped fields
end

function show_field(structure::EditableStructure, field::Symbol, value::Any)
    #unmapped fields
end

# Non-removable fields
function show_field(structure::EditableStructure, field::Symbol, value::Union{TransformModule.Transform})
    typeName = split(string(typeof(value)), ".")[end]
    if CImGui.CollapsingHeader(replace(typeName, "Internal" => ""))
        display_fields(value)
    end
end

# Removable fields
function show_field(structure::EditableStructure, field::Symbol, value::Union{EditableComponent})
    typeName = split(string(typeof(value)), ".")[end]
    closableHeader = Ref(true)
    if CImGui.CollapsingHeader(replace(typeName, "Internal" => ""), closableHeader)
        display_fields(value)
    end
    if !closableHeader[]
        # remove the component from the structure
        JulGame.EditorState[DELETE_CONFIRMATION] = () -> setproperty!(structure, field, C_NULL)
    end
end


function show_field_label(field::Symbol)
    # capitalize the first letter
    toolTip = get(ToolTips, field, "")
    label = string(field)
    label = uppercase(label[1]) * label[2:end]
    # Space between each word (capital letter)
    label = replace(label, r"(?<=[a-z])(?=[A-Z])" => " ")#replace(label, r"(?=[A-Z])" => " ")
    label = strip(label)

    CImGui.Text("$(label)")
    if toolTip != ""
        CImGui.SameLine()
        show_help_marker("$(toolTip)")
    end
end