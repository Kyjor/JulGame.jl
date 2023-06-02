module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64
    using ImGuiGLFWBackend #CImGui.GLFWBackend
    using ImGuiOpenGLBackend #CImGui.OpenGLBackend
    using ImGuiGLFWBackend.LibGLFW # #CImGui.OpenGLBackend.GLFW
    using ImGuiOpenGLBackend.ModernGL
    #using Printf
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    using ..julGame.EntityModule
    using ..julGame.SceneWriterModule

    include("../../src/Macros.jl")
    include("./MainMenuBar.jl")
    include("./EntityContextMenu.jl")
    include("./ComponentInputs.jl")

    function setProjectPath(projectPath)
        game = C_NULL
        try
            include(joinpath(projectPath, "projectFiles", "src", "Entry.jl")); 
            game = Base.@invokelatest Entry.run(true, "scene.json");
        catch e
            println(e)
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
    
            # glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
            # glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # 3.0+ only
        end
    
        # setup GLFW error callback
        #? error_callback(err::GLFW.GLFWError) = @error "GLFW ERROR: code $(err.code) msg: $(err.description)"
        #? GLFW.SetErrorCallback(error_callback)
    
        # create window
        game = C_NULL #Entry.run(true)
        window = glfwCreateWindow(1920, 1080, "Demo", C_NULL, C_NULL)
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
    
        # load Fonts
        # - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use `CImGui.PushFont/PopFont` to select them.
        # - `CImGui.AddFontFromFileTTF` will return the `Ptr{ImFont}` so you can store it if you need to select the font among multiple.
        # - If the file cannot be loaded, the function will return C_NULL. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
        # - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling `CImGui.Build()`/`GetTexDataAsXXXX()``, which `ImGui_ImplXXXX_NewFrame` below will call.
        # - Read 'fonts/README.txt' for more instructions and details.
        fonts_dir = joinpath(@__DIR__, "..", "fonts")
        fonts = unsafe_load(CImGui.GetIO().Fonts)
        # default_font = CImGui.AddFontDefault(fonts)
        CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Roboto-Medium.ttf"), 16)
        # @assert default_font != C_NULL
    
        # setup Platform/Renderer bindings
        glfw_ctx = ImGuiGLFWBackend.create_context(window, install_callbacks = true)
        ImGuiGLFWBackend.init(glfw_ctx)
        opengl_ctx = ImGuiOpenGLBackend.create_context(glsl_version)
        ImGuiOpenGLBackend.init(opengl_ctx)
        try
            cameraPositionX = 0.0
            cameraPositionY = 0.0
            currentEntitySelected = C_NULL
            currentEntitySelectedIndex = -1
            currentEntityUpdated = false
            editorWindowSizeX = 0
            editorWindowSizeY = 0
            entities = []
            gameInfo = []
            mousePosition = C_NULL
            projectPath = ""
            relativeX = 0
            relativeY = 0
            show_demo_window = true
            show_another_window = false
            clear_color = Cfloat[0.45, 0.55, 0.60, 0.01]
            while glfwWindowShouldClose(window) == 0
                resetCamera = false
                update = []
                if (gameInfo !== nothing && length(gameInfo) > 0)
                    entities = gameInfo[1]
                    mousePosition = gameInfo[2]
                    cameraPositionX = gameInfo[3].x
                    cameraPositionY = gameInfo[3].y
                end 
                glfwPollEvents()
                # start the Dear ImGui frame
                ImGuiOpenGLBackend.new_frame(opengl_ctx) #ImGui_ImplOpenGL3_NewFrame()
                ImGuiGLFWBackend.new_frame(glfw_ctx) #ImGui_ImplGlfw_NewFrame()
                CImGui.NewFrame()
    
                event = @event begin
                    serializeEntities(entities, projectPath, "scene")
                end
                events = [event]
                # show the big demo window
                @c ShowMainMenuBar(Ref{Bool}(true), events)
    
                @c CImGui.ShowDemoWindow(Ref{Bool}(true))
                testText = ""
                mousePositionText = "0,0"
                if length(entities) > 0 && currentEntitySelected != C_NULL
                    testText = currentEntitySelected.name
                end
                if mousePosition != C_NULL
                    mousePositionText = "$(mousePosition.x),$(mousePosition.y)"
                end
    
                # show a simple window that we create ourselves.
                # we use a Begin/End pair to created a named window.
                @cstatic f=Cfloat(0.0) counter=Cint(0) begin
                    CImGui.Begin("Item")  # create a window called "Item" and append into it.
    
                    CImGui.Text(testText)  # display some text
                
                    # @c CImGui.Checkbox("Demo Window", &show_demo_window)  # edit bools storing our window open/close state
                    
                    if currentEntityUpdated 
                        currentEntityUpdated = false
                    end
                    if currentEntitySelectedIndex != -1
                        CImGui.Button("Delete") && (deleteat!(entities, currentEntitySelectedIndex); currentEntitySelected = C_NULL; currentEntitySelectedIndex = -1;)
                    end
                    if currentEntitySelected != C_NULL
                        CImGui.PushID("foo")
                        if CImGui.BeginMenu("Entity Menu")
                            ShowEntityContextMenu(currentEntitySelected)
                            CImGui.EndMenu()
                        end
                        CImGui.PopID()
                        CImGui.Separator()
                        
                        FieldsInStruct=fieldnames(julGame.Entity);
                        for i = 1:length(FieldsInStruct)
                            #Check field i
                            Value=getfield(currentEntitySelected, FieldsInStruct[i])
                            
                            if typeof(Value) == Bool
                                @c CImGui.Checkbox("$(FieldsInStruct[i])", &Value)
                                setfield!(currentEntitySelected,FieldsInStruct[i],Value)
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
                                setfield!(currentEntitySelected,FieldsInStruct[i], currentTextInTextBox)
                            elseif FieldsInStruct[i] == :components
                                for i = 1:length(Value)
                                    component = Value[i]
                                    componentType = "$(typeof(component).name.wrapper)"
                                    componentType = String(split(componentType, '.')[length(split(componentType, '.'))])
    
                                    if CImGui.TreeNode(componentType)
                                        CImGui.Button("Delete") && (deleteat!(Value, i); break;)
                                        ShowComponentProperties(currentEntitySelected, component, componentType)
                                        CImGui.TreePop()
                                    end
                                end
                            end
                        end
                    end
    
        #            @c CImGui.InputInt("y", &i0)
                    #CImGui.Text(@sprintf("Application average %.3f ms/frame (%.1f FPS)", 1000 / unsafe_load(CImGui.GetIO().Framerate), unsafe_load(CImGui.GetIO().Framerate)))
                    CImGui.Text(mousePositionText)
                    push!(update, [currentEntitySelected, 0])
                    CImGui.End()
                end
                @cstatic begin
                    CImGui.Begin("Scene")  # create a window called "Scene"
                    CImGui.Text("Window Size: x:$editorWindowSizeX, y:$editorWindowSizeY Camera Position: x:$cameraPositionX, y:$cameraPositionY")
                    CImGui.SameLine()
                    CImGui.Button("ResetCamera") && (resetCamera = true)
                    relativeX = CImGui.GetWindowPos().x + 3
                    relativeY = CImGui.GetWindowPos().y + 45
                    editorWindowSizeX = CImGui.GetWindowSize().x - 6
                    editorWindowSizeY = CImGui.GetWindowSize().y - 50
                    CImGui.End()
                end
                @cstatic begin
                    CImGui.Begin("Project Location")  # create a window called "Project Location"
                    CImGui.Text("Enter full path to project Entry.jl file")
                    buf = "$(projectPath)"*"\0"^(128)
                    CImGui.InputText("", buf, length(buf))
                    currentTextInTextBox = ""
                    for characterIndex = 1:length(buf)
                        if Int(buf[characterIndex]) == 0 
                            if characterIndex != 1
                                currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                            end
                            break
                        end
                    end
                    projectPath = currentTextInTextBox
                    CImGui.Button("Open Project") && (game = setProjectPath(projectPath))
                    CImGui.End()
                end

                @cstatic begin
                    CImGui.Begin("Hierarchy")  
                    #CImGui.Button("New entity") && (game.createNewEntity())
    
                    if CImGui.TreeNode("Level_0")
                        #ShowHelpMarker("This is a more standard looking tree with selectable nodes.\nClick to select, CTRL+Click to toggle, click on arrows or double-click to open.")
                        align_label_with_current_x_position= @cstatic align_label_with_current_x_position=false begin
                            #@c CImGui.Checkbox("Align label with current X position)", &align_label_with_current_x_position)
                            align_label_with_current_x_position && CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())
                        end
            
                        @cstatic selection_mask=Cint(1 << 2) begin  # dumb representation of what may be user-side selection state. You may carry selection state inside or outside your objects in whatever format you see fit.
                            node_clicked = -1  # temporary storage of what node we have clicked to process selection at the end of the loop. May be a pointer to your own node type, etc.
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
                                CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "$(entities[i].name)")
                                CImGui.IsItemClicked() && (node_clicked = i; currentEntitySelected = entities[i]; currentEntitySelectedIndex = i; currentEntityUpdated = true;)
                            end
                            if node_clicked != -1
                                selection_mask = 1 << node_clicked            # Click to single-select
                            end
                            CImGui.PopStyleVar()
                        end # @cstatic
                        align_label_with_current_x_position && CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                        CImGui.TreePop()
                    end
                    CImGui.TreePop()
                    CImGui.End()
                end
    
                # show another simple window.
                if show_another_window
                    @c CImGui.Begin("Another Window", &show_another_window)  # pass a pointer to our bool variable (the window will have a closing button that will clear the bool when clicked)
                    CImGui.Text("Hello from another window!")
                    CImGui.Button("Close Me") && (show_another_window = false;)
                    CImGui.End()
                end
                x,y = Int[1], Int[1]
                glfwGetWindowPos(window, pointer(x), pointer(y))
                push!(update, x[1] + relativeX)
                push!(update, y[1] + relativeY)
                push!(update, editorWindowSizeX)
                push!(update, editorWindowSizeY)
                push!(update, resetCamera)
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
                gameInfo = game == C_NULL ? [] : game.editorLoop(update)
            end
        catch e
            @error "Error in renderloop!" exception=e
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