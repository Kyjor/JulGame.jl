
module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64, LibCImGui
    using ImGuiGLFWBackend #CImGui.GLFWBackend
    using ImGuiOpenGLBackend #CImGui.OpenGLBackend
    using ImGuiGLFWBackend.LibGLFW # #CImGui.OpenGLBackend.GLFW
    using ImGuiOpenGLBackend.ModernGL
    #using Printf
    using ..JulGame
    using ..JulGame.EntityModule
    using ..JulGame.SceneWriterModule
    using ..JulGame.SceneLoaderModule
    using ..JulGame.TextBoxModule

    include("../../Macros.jl")
    include("./MainMenuBar.jl")
    include("./EntityContextMenu.jl")
    include("./ComponentInputs.jl")
    include("./TextBoxFields.jl")
    include("./Utils.jl")

    # function createObject(args...)
    #     for (i, arg) in enumerate(args)
    #         println("Arg #$i = $(arg[1])")
    #         var"$(arg[1])" = arg[2]
    #     end

    #     () -> (begin
    #         var"$(arg[1])";
    #     end for (i, arg) in enumerate(args))
    # end

    function scriptObj(name::String, parameters::Array)
        () -> (name; parameters)
    end

    function loadScene(projectPath, sceneFileName)
        game = C_NULL
        try
            game = SceneLoaderModule.loadScene(sceneFileName, projectPath, true);
        catch e 
            println(e)
            Base.show_backtrace(stdout, catch_backtrace())
        end

        return game
    end

    function run()
        @static if Sys.isapple()
            # OpenGL 3.2 + GLSL 150
            glsl_version = 150
            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
            glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
            glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
        else
            # OpenGL 3.0 + GLSL 130
            glsl_version = 130
            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)
        end
    
        # create window
        game = C_NULL #Entry.run(true)
        window = glfwCreateWindow(1920, 1080, "JulGame v0.1.0", C_NULL, C_NULL)
        @assert window != C_NULL
        glfwMakeContextCurrent(window)
        glfwSwapInterval(1)  # enable vsync
    
        # setup Dear ImGui context
        ctx = CImGui.CreateContext()
    
        io = CImGui.GetIO()
        io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable
    
        # setup Dear ImGui style
        CImGui.StyleColorsDark()
        # CImGui.StyleColorsClassic()
        # CImGui.StyleColorsLight()
    
        # setup Platform/Renderer bindings
        glfw_ctx = ImGuiGLFWBackend.create_context(window, install_callbacks = true)
        ImGuiGLFWBackend.init(glfw_ctx)
        opengl_ctx = ImGuiOpenGLBackend.create_context(glsl_version)
        ImGuiOpenGLBackend.init(opengl_ctx)
        try
            cameraPositionX = 0.0
            cameraPositionY = 0.0
            currentEntitySelectedIndex = -1
            currentEntityUpdated = false
            currentTextBoxSelectedIndex = -1
            currentTextBoxUpdated = false
            editorWindowSizeX = 0
            editorWindowSizeY = 0
            entities = []
            textBoxes = []
            screenButtons = []
            gameInfo = []
            mousePosition = C_NULL
            projectPath = ""
            sceneFileName = ""
            relativeX = 0
            relativeY = 0
            isEditorWindowFocused = false
            isSceneWindowFocused = false
            isSceneWindowRestored = true
            autoMinimize = false
            isMinimized = false

            clear_color = Cfloat[0.45, 0.55, 0.60, 0.01]
            while glfwWindowShouldClose(window) == 0
                try
                    resetCamera = false
                    update = []
                    if (gameInfo !== nothing && length(gameInfo) > 0)
                        entities = gameInfo[1][1]
                        textBoxes = gameInfo[1][2]
                        screenButtons = gameInfo[1][3]
                        mousePosition = gameInfo[2]
                        cameraPositionX = gameInfo[3].x
                        cameraPositionY = gameInfo[3].y
                        currentEntitySelectedIndex = gameInfo[4]
                        isSceneWindowFocused = gameInfo[5]
                    end 
                    
                    glfwPollEvents()
                    # start the Dear ImGui frame
                    ImGuiOpenGLBackend.new_frame(opengl_ctx) #ImGui_ImplOpenGL3_NewFrame()
                    ImGuiGLFWBackend.new_frame(glfw_ctx) #ImGui_ImplGlfw_NewFrame()
                    CImGui.NewFrame()
        
                    event = @event begin
                        serializeEntities(entities, textBoxes, projectPath, "$(sceneFileName).json")
                    end
                    events = [event]
                    @c ShowMainMenuBar(Ref{Bool}(true), events)
                    
                    # Uncomment to see widgets that can be used.
                    #@c CImGui.ShowDemoWindow(Ref{Bool}(true)) 
                    testText = ""
                    mousePositionText = "0,0"
                    if currentEntitySelectedIndex != -1
                        currentEntitySelectedIndex = min(max(0, currentEntitySelectedIndex), length(entities))
                        if length(entities) > 0
                            testText = entities[currentEntitySelectedIndex].name
                        end
                    end
                    if mousePosition != C_NULL
                        mousePositionText = "$(mousePosition.x),$(mousePosition.y)"
                    end
        

                    LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL) # Creating the "dockspace" that covers the whole window. This allows the child windows to automatically resize.

                    # we use a Begin/End pair to created a named window.
                    @cstatic f=Cfloat(0.0) counter=Cint(0) begin
                        CImGui.Begin("Item")  # create a window called "Item" and append into it.

                        if glfwGetWindowAttrib(window, GLFW_FOCUSED) != 0 && glfwGetWindowAttrib(window, GLFW_HOVERED) != 0
                            isEditorWindowFocused = true
                        elseif glfwGetWindowAttrib(window, GLFW_FOCUSED) == 0
                            isEditorWindowFocused = false
                        end
                        if isEditorWindowFocused && !isSceneWindowFocused && gameInfo !== nothing && length(gameInfo) > 0 && !isSceneWindowRestored
                            #println("Editor Window Focused")
                            isSceneWindowRestored = true
                            game.restoreWindow()
                        elseif isSceneWindowFocused && !isEditorWindowFocused
                            #println("Scene Window Focused")
                        elseif !isEditorWindowFocused && !isSceneWindowFocused && isSceneWindowRestored && gameInfo !== nothing && length(gameInfo) > 0 && autoMinimize
                            isSceneWindowRestored = false
                            #println("Both Windows Not Focused")
                            game.minimizeWindow()
                        end

                        CImGui.Text(testText)
                        
                        if currentEntityUpdated 
                            currentEntityUpdated = false
                        end
                        if ((currentEntitySelectedIndex != -1 || currentTextBoxSelectedIndex != -1) && currentEntitySelectedIndex != currentTextBoxSelectedIndex)
                            currentSelectedIndex = currentEntitySelectedIndex != -1 ? currentEntitySelectedIndex : currentTextBoxSelectedIndex
                            structToUpdate = currentEntitySelectedIndex != -1 ? entities : textBoxes
                            CImGui.Button("Delete") && (deleteat!(structToUpdate, currentSelectedIndex); currentEntitySelectedIndex = -1; currentTextBoxSelectedIndex = -1; continue;)
                            CImGui.NewLine()
                            CImGui.NewLine()
                            CImGui.Button("Duplicate") && (push!(structToUpdate, deepcopy(structToUpdate[currentSelectedIndex])); currentEntitySelectedIndex = currentEntitySelectedIndex != -1 ? length(entities) : -1; currentTextBoxSelectedIndex != -1 ? length(textBoxes) : -1;)
                            tempEntity = structToUpdate[currentSelectedIndex]
                            CImGui.Button("Move Up") && currentSelectedIndex > 1 && (structToUpdate[currentSelectedIndex] = structToUpdate[currentSelectedIndex - 1]; structToUpdate[currentSelectedIndex - 1] = tempEntity; currentEntitySelectedIndex -= currentEntitySelectedIndex != -1 ? 1 : 0; currentTextBoxSelectedIndex -= currentTextBoxSelectedIndex != -1 ? 1 : 0;)
                            CImGui.Button("Move Down") && currentSelectedIndex < length(structToUpdate) && (structToUpdate[currentSelectedIndex] = structToUpdate[currentSelectedIndex + 1]; structToUpdate[currentSelectedIndex + 1] = tempEntity; currentEntitySelectedIndex += currentEntitySelectedIndex != -1 ? 1 : 0; currentTextBoxSelectedIndex += currentTextBoxSelectedIndex != -1 ? 1 : 0;)

                            CImGui.PushID("foo")
                            if CImGui.BeginMenu("Add")
                                ShowEntityContextMenu(projectPath, structToUpdate[currentSelectedIndex], game)
                                CImGui.EndMenu()
                            end
                            CImGui.PopID()
                            CImGui.Separator()
                            
                            FieldsInStruct=fieldnames(currentEntitySelectedIndex != -1 ? JulGame.Entity : TextBoxModule.TextBox);
                            for i = 1:length(FieldsInStruct)
                                #Check field i
                                try
                                    Value=getfield(structToUpdate[currentSelectedIndex], FieldsInStruct[i])
                                    
                                    if currentTextBoxSelectedIndex > 0
                                        ShowTextBoxField(structToUpdate[currentSelectedIndex], FieldsInStruct[i])
                                    elseif typeof(Value) == Bool
                                        @c CImGui.Checkbox("$(FieldsInStruct[i])", &Value)
                                        setfield!(structToUpdate[currentSelectedIndex],FieldsInStruct[i],Value)
                                    elseif typeof(Value) == String
                                        buf = "$(Value)"*"\0"^(64)
                                        CImGui.InputText("$(FieldsInStruct[i])", buf, length(buf))
                                        currentTextInTextBox = ""
                                        for characterIndex = 1:length(buf)
                                            if Int(buf[characterIndex]) == 0 
                                                if characterIndex != 1
                                                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                                                end
                                                break
                                            end
                                        end
                                        setfield!(structToUpdate[currentSelectedIndex],FieldsInStruct[i], currentTextInTextBox)
                                    elseif FieldsInStruct[i] == :components
                                        for i = 1:length(Value)
                                            component = Value[i]
                                            componentType = "$(typeof(component).name.wrapper)"
                                            componentType = String(split(componentType, '.')[length(split(componentType, '.'))])
            
                                            if CImGui.TreeNode(componentType)
                                                CImGui.Button("Delete") && (deleteat!(Value, i); break;)
                                                ShowComponentProperties(structToUpdate[currentSelectedIndex], component, componentType)
                                                CImGui.TreePop()
                                            end
                                        end
                                    elseif FieldsInStruct[i] == :scripts
                                        if CImGui.TreeNode("Scripts")
                                            CImGui.Button("Add Script") && (push!(structToUpdate[currentSelectedIndex].scripts, scriptObj("",[])); break;)
                                            for i = 1:length(Value)
                                                if CImGui.TreeNode("Script $(i)")
                                                    buf = "$(Value[i].name)"*"\0"^(64)
                                                    CImGui.Button("Delete $(i)") && (deleteat!(structToUpdate[currentSelectedIndex].scripts, i); break;)
                                                    CImGui.InputText("Script $(i)", buf, length(buf))
                                                    currentTextInTextBox = ""
                                                    for characterIndex = 1:length(buf)
                                                        if Int(buf[characterIndex]) == 0 
                                                            if characterIndex != 1
                                                                currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                                                            end
                                                            break
                                                        end
                                                    end
                                                    
                                                    structToUpdate[currentSelectedIndex].scripts[i] = scriptObj(currentTextInTextBox, structToUpdate[currentSelectedIndex].scripts[i].parameters)
                                                    if CImGui.TreeNode("Script $(i) parameters")
                                                        params = structToUpdate[currentSelectedIndex].scripts[i].parameters
                                                        CImGui.Button("Add New Script Parameter") && (push!(params, ""); structToUpdate[currentSelectedIndex].scripts[i] = scriptObj(currentTextInTextBox, params); break;)

                                                        for j = 1:length(structToUpdate[currentSelectedIndex].scripts[i].parameters)
                                                            buf = "$(structToUpdate[currentSelectedIndex].scripts[i].parameters[j])"*"\0"^(64)
                                                            CImGui.Button("pDelete $(j)") && (deleteat!(params, j); structToUpdate[currentSelectedIndex].scripts[i] = scriptObj(currentTextInTextBox, params); break;)
                                                            CImGui.InputText("Parameter $(j)", buf, length(buf))
                                                            currentTextInTextBox = ""
                                                            for characterIndex = 1:length(buf)
                                                                if Int(buf[characterIndex]) == 0 
                                                                    if characterIndex != 1
                                                                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                                                                    end
                                                                    break
                                                                end
                                                            end
                                                            params[j] = currentTextInTextBox
                                                            structToUpdate[currentSelectedIndex].scripts[i] = scriptObj(structToUpdate[currentSelectedIndex].scripts[i].name, params)

                                                        end
                                                        CImGui.TreePop()
                                                    end
                                                    CImGui.TreePop()
                                                end
                                            end
                                            CImGui.TreePop()
                                        end
                                    end
                                catch e
                                    println(e)
                                    Base.show_backtrace(stdout, catch_backtrace())
                                end
                            end
                        end
        
                        CImGui.Text(mousePositionText)
                        entityToPush = C_NULL
                        if currentEntitySelectedIndex != -1
                            entityToPush = entities[currentEntitySelectedIndex]
                        end
                        push!(update, [entityToPush, 0])
                        CImGui.End()
                    end

                    @cstatic begin
                        CImGui.Begin("Debug")
                        CImGui.Text("To be implemented")
                        CImGui.End()
                    end

                    @cstatic begin
                        CImGui.Begin("Scene")  # create a window called "Scene"
                        CImGui.Text("Window Size: x:$editorWindowSizeX, y:$editorWindowSizeY Camera Position: x:$cameraPositionX, y:$cameraPositionY")
                        CImGui.SameLine()
                        CImGui.Button("ResetCamera") && (resetCamera = true)
                        CImGui.SameLine()
                        @c CImGui.Checkbox("Auto Minimize When Losing Focus", &autoMinimize)
                        CImGui.SameLine()
                        CImGui.Button("Minimize/Restore") && gameInfo !== nothing && length(gameInfo) > 0 && (!isMinimized ? game.minimizeWindow() : game.restoreWindow(); isMinimized = !isMinimized)
                        relativeX = CImGui.GetWindowPos().x + 3
                        relativeY = CImGui.GetWindowPos().y + 45
                        editorWindowSizeX = CImGui.GetWindowSize().x - 100
                        editorWindowSizeY = CImGui.GetWindowSize().y - 100
                        CImGui.End()
                    end
                    @cstatic begin
                        CImGui.Begin("Play & Build") 
                        entryPath = "$(joinpath(projectPath, "src"))"
                        scriptPath = "$(joinpath(pwd(), "..", "EditorScripts", "RunScene.bat"))"

                        try
                            CImGui.Button("Play") && (Threads.@spawn Base.run(`cmd /c $scriptPath $entryPath`); println("Running $scriptPath $entryPath");)
                        catch e
                            println(e)
                        end
                        CImGui.End()
                    end
                    @cstatic begin
                        CImGui.Begin("Project Location")  # create a window called "Project Location"
                        CImGui.Text("Enter full path to root project folder and the name of scene file to load.")
                        buf = "$(projectPath)"*"\0"^(128)
                        buf1 = "$(sceneFileName)"*"\0"^(128)
                        CImGui.InputText("Project Root Folder", buf, length(buf))
                        CImGui.InputText("Scene File Name", buf1, length(buf1))
                        currentTextInTextBox = ""
                        currentTextInTextBox1 = ""
                        for characterIndex = 1:length(buf)
                            if Int(buf[characterIndex]) == 0 
                                if characterIndex != 1
                                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                                end
                                break
                            end
                        end
                        for characterIndex = 1:length(buf1)
                            if Int(buf1[characterIndex]) == 0 
                                if characterIndex != 1
                                    currentTextInTextBox1 = String(SubString(buf1, 1, characterIndex-1))
                                end
                                break
                            end
                        end
                        projectPath = currentTextInTextBox
                        sceneFileName = currentTextInTextBox1
                        CImGui.Button("Load Scene") && (game = loadScene("$(sceneFileName).json", projectPath))
                        CImGui.End()
                    end

                    CImGui.Begin("Hierarchy") 
                    if gameInfo !== nothing && length(gameInfo) > 0 
                        try
                            CImGui.Button("New entity") && (game.createNewEntity())
                            CImGui.Button("New textbox") && (game.createNewTextBox(joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf")))                    
                        catch e
                            println(e)
                        end
                    else
                        CImGui.Text("Load a project in the 'Project Location' window to add entities and textboxes.")
                    end 
        
                    ShowHelpMarker("This is a list of all entities in the scene. Click on an entity to select it.")
                    CImGui.SameLine()
                    if CImGui.TreeNode("Entities")
                        CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())
            
                        @cstatic selection_mask=Cint(1 << 2) begin  # dumb representation of what may be user-side selection state. You may carry selection state inside or outside your objects in whatever format you see fit.
                            node_clicked = currentEntitySelectedIndex  # temporary storage of what node we have clicked to process selection at the end of the loop. May be a pointer to your own node type, etc.
                            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_IndentSpacing, CImGui.GetFontSize()*3) # increase spacing to differentiate leaves from expanded contents.
                            for i = 0:5
                                continue
                                # disable the default open on single-click behavior and pass in Selected flag according to our selection state.
                                node_flags = CImGui.ImGuiTreeNodeFlags_OpenOnArrow | CImGui.ImGuiTreeNodeFlags_OpenOnDoubleClick | ((selection_mask & (1 << i)) != 0 ? CImGui.ImGuiTreeNodeFlags_Selected : 0)
                                if i < 3
                                    # Node
                                    node_open = CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "Selectable Node $i")
                                    CImGui.IsItemClicked() && (node_clicked = i;)
                                    node_open && (CImGui.Text("Blah blah\nBlah Blah"); CImGui.TreePop();)
                                else
                                    # Leaf: The only reason we have a TreeNode at all is to allow selection of the leaf. Otherwise we can use BulletText() or TreeAdvanceToLabelPos()+Text().
                                    node_flags |= CImGui.ImGuiTreeNodeFlags_Leaf | CImGui.ImGuiTreeNodeFlags_NoTreePushOnOpen # CImGui.ImGuiTreeNodeFlags_Bullet
                                    CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "Selectable Leaf $i")
                                    CImGui.IsItemClicked() && (node_clicked = i;)
                                end
                            end
                            for i in 1:length(entities)
                                # disable the default open on single-click behavior and pass in Selected flag according to our selection state.
                                node_flags = CImGui.ImGuiTreeNodeFlags_OpenOnArrow | CImGui.ImGuiTreeNodeFlags_OpenOnDoubleClick | ((selection_mask & (1 << i)) != 0 ? CImGui.ImGuiTreeNodeFlags_Selected : 0)
                                # Leaf: The only reason we have a TreeNode at all is to allow selection of the leaf. Otherwise we can use BulletText() or TreeAdvanceToLabelPos()+Text().
                                node_flags |= CImGui.ImGuiTreeNodeFlags_Leaf | CImGui.ImGuiTreeNodeFlags_NoTreePushOnOpen # CImGui.ImGuiTreeNodeFlags_Bullet
                                CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "$(i): $(entities[i].name)")
                                CImGui.IsItemClicked() && (node_clicked = i; currentEntitySelectedIndex = i; currentEntityUpdated = true; currentTextBoxSelectedIndex = -1)
                            end
                            if node_clicked != -1
                                selection_mask = 1 << node_clicked            # Click to single-select
                            end
                            CImGui.PopStyleVar()
                        end # @cstatic
                        CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                        CImGui.TreePop()
                    end
                    ShowHelpMarker("This is a list of all entities in the scene. Click on an entity to select it.")
                    CImGui.SameLine()
                    if CImGui.TreeNode("Textbox")
                        CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())
            
                        @cstatic selection_mask=Cint(1 << 2) begin  # dumb representation of what may be user-side selection state. You may carry selection state inside or outside your objects in whatever format you see fit.
                            node_clicked = currentTextBoxSelectedIndex  # temporary storage of what node we have clicked to process selection at the end of the loop. May be a pointer to your own node type, etc.
                            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_IndentSpacing, CImGui.GetFontSize()*3) # increase spacing to differentiate leaves from expanded contents.
                            for i = 0:5
                                continue
                                # disable the default open on single-click behavior and pass in Selected flag according to our selection state.
                                node_flags = CImGui.ImGuiTreeNodeFlags_OpenOnArrow | CImGui.ImGuiTreeNodeFlags_OpenOnDoubleClick | ((selection_mask & (1 << i)) != 0 ? CImGui.ImGuiTreeNodeFlags_Selected : 0)
                                if i < 3
                                    # Node
                                    node_open = CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "Selectable Node $i")
                                    CImGui.IsItemClicked() && (node_clicked = i;)
                                    node_open && (CImGui.Text("Blah blah\nBlah Blah"); CImGui.TreePop();)
                                else
                                    # Leaf: The only reason we have a TreeNode at all is to allow selection of the leaf. Otherwise we can use BulletText() or TreeAdvanceToLabelPos()+Text().
                                    node_flags |= CImGui.ImGuiTreeNodeFlags_Leaf | CImGui.ImGuiTreeNodeFlags_NoTreePushOnOpen # CImGui.ImGuiTreeNodeFlags_Bullet
                                    CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "Selectable Leaf $i")
                                    CImGui.IsItemClicked() && (node_clicked = i;)
                                end
                            end
                            for i in 1:length(textBoxes)
                                # disable the default open on single-click behavior and pass in Selected flag according to our selection state.
                                node_flags = CImGui.ImGuiTreeNodeFlags_OpenOnArrow | CImGui.ImGuiTreeNodeFlags_OpenOnDoubleClick | ((selection_mask & (1 << i)) != 0 ? CImGui.ImGuiTreeNodeFlags_Selected : 0)
                                # Leaf: The only reason we have a TreeNode at all is to allow selection of the leaf. Otherwise we can use BulletText() or TreeAdvanceToLabelPos()+Text().
                                node_flags |= CImGui.ImGuiTreeNodeFlags_Leaf | CImGui.ImGuiTreeNodeFlags_NoTreePushOnOpen # CImGui.ImGuiTreeNodeFlags_Bullet
                                CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "$(i): $(textBoxes[i].name)")
                                CImGui.IsItemClicked() && (node_clicked = i; currentTextBoxSelectedIndex = i; currentTextBoxUpdated = true; currentEntitySelectedIndex = -1)
                            end
                            if node_clicked != -1
                                selection_mask = 1 << node_clicked            # Click to single-select
                            end
                            CImGui.PopStyleVar()
                        end # @cstatic
                        CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                        CImGui.TreePop()
                    end
                    CImGui.End()
        
                    x,y = Int[1], Int[1]
                    glfwGetWindowPos(window, pointer(x), pointer(y))
                    push!(update, x[1] + relativeX)
                    push!(update, y[1] + relativeY)
                    push!(update, editorWindowSizeX)
                    push!(update, editorWindowSizeY)
                    push!(update, resetCamera)
                    push!(update, currentEntitySelectedIndex)
                    # rendering
                    CImGui.Render()
                    glfwMakeContextCurrent(window)
        
                    width, height = Ref{Cint}(), Ref{Cint}() #! need helper fcn
                    glfwGetFramebufferSize(window, width, height)
                    display_w = width[]
                    display_h = height[]
                    
                    glViewport(0, 0, display_w, display_h)
                    glClearColor(clear_color...)
                    glClear(GL_COLOR_BUFFER_BIT)
                    ImGuiOpenGLBackend.render(opengl_ctx) #ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
        
                    glfwMakeContextCurrent(window)
                    glfwSwapBuffers(window)
                    gameInfo = game == C_NULL ? [] : game.gameLoop(Ref(UInt64(0)), Ref(UInt64(0)), Ref(Bool(false)), true, update)
                catch e 
                    println(e)
                    Base.show_backtrace(stdout, catch_backtrace())
                end
            end
        catch e
            @warn "Error in renderloop!" exception=e
            Base.show_backtrace(stderr, catch_backtrace())
        finally
            ImGuiOpenGLBackend.shutdown(opengl_ctx) #ImGui_ImplOpenGL3_Shutdown()
            ImGuiGLFWBackend.shutdown(glfw_ctx) #ImGui_ImplGlfw_Shutdown()
            CImGui.DestroyContext(ctx)
            glfwDestroyWindow(window)
            SDL2.Mix_Quit()
            SDL2.SDL_Quit()
        end
    end

    julia_main() = run()
end