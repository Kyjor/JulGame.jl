using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using ImGuiGLFWBackend #CImGui.GLFWBackend
using ImGuiOpenGLBackend #CImGui.OpenGLBackend
using ImGuiGLFWBackend.LibGLFW # #CImGui.OpenGLBackend.GLFW
using ImGuiOpenGLBackend.ModernGL
using Printf
using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer

include("../demos/platformer/src/platformer.jl")
@static if Sys.isapple()
    # OpenGL 3.2 + GLSL 150
    const glsl_version = 150
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
else
    # OpenGL 3.0 + GLSL 130
    const glsl_version = 130
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)

    # glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
    # glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # 3.0+ only
end

# setup GLFW error callback
#? error_callback(err::GLFW.GLFWError) = @error "GLFW ERROR: code $(err.code) msg: $(err.description)"
#? GLFW.SetErrorCallback(error_callback)

# create window
game = platformer.runEditor()
window = glfwCreateWindow(1920, 1080, "Demo", C_NULL, C_NULL)
@assert window != C_NULL
glfwMakeContextCurrent(window)
glfwSwapInterval(1)  # enable vsync

# setup Dear ImGui context
ctx = CImGui.CreateContext()

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
    editorWindowSizeX = 0
    editorWindowSizeY = 0
    entities = []
    gameInfo = []
    mousePosition = C_NULL
    relativeX = 0
    relativeY = 0
    show_demo_window = true
    show_another_window = false
    clear_color = Cfloat[0.45, 0.55, 0.60, 0.01]
    while glfwWindowShouldClose(window) == 0
        update = []
        if (length(gameInfo) > 0)
            entities = gameInfo[1]
            mousePosition = gameInfo[2]
        end 
        glfwPollEvents()
        # start the Dear ImGui frame
        ImGuiOpenGLBackend.new_frame(opengl_ctx) #ImGui_ImplOpenGL3_NewFrame()
        ImGuiGLFWBackend.new_frame(glfw_ctx) #ImGui_ImplGlfw_NewFrame()
        CImGui.NewFrame()

        # show the big demo window
        #show_demo_window && @c CImGui.ShowDemoWindow(&show_demo_window)
        testText = "This is some useful text."
        mousePositionText = "0,0"
        if length(entities) > 0
            testText = entities[1].name
        end
        if mousePosition != C_NULL
            mousePositionText = "$(mousePosition.x),$(mousePosition.y)"
        end
        # show a simple window that we create ourselves.
        # we use a Begin/End pair to created a named window.
        @cstatic f=Cfloat(0.0) counter=Cint(0) i0=Cint(0) begin
            CImGui.Begin("Item")  # create a window called "Hello, world!" and append into it.
            CImGui.Text(testText)  # display some text
            # @c CImGui.Checkbox("Demo Window", &show_demo_window)  # edit bools storing our window open/close state
            # @c CImGui.Checkbox("Another Window", &show_another_window)

            # @c CImGui.SliderFloat("float", &f, 0, 1)  # edit 1 float using a slider from 0 to 1
            # CImGui.ColorEdit3("clear color", clear_color)  # edit 3 floats representing a color
            # CImGui.Button("Button") && (counter += 1)
            # CImGui.SameLine()
            # CImGui.Text("counter = $counter")
            @c CImGui.InputInt("input int", &i0)
            CImGui.Text(@sprintf("Application average %.3f ms/frame (%.1f FPS)", 1000 / unsafe_load(CImGui.GetIO().Framerate), unsafe_load(CImGui.GetIO().Framerate)))
            CImGui.Text(mousePositionText)
            push!(update, i0)
            CImGui.End()
            #println(CImGui.GetWindowSize())
        end

        @cstatic begin
            CImGui.Begin("Scene")  # create a window called "Hello, world!" and append into it.
            #CImGui.Begin("Scene (x:$(editorWindowSizeX),y:$(editorWindowSizeY))")  # create a window called "Hello, world!" and append into it.
            CImGui.Text("Window Size: x:$editorWindowSizeX, y:$editorWindowSizeY")
            relativeX = CImGui.GetWindowPos().x + 3
            relativeY = CImGui.GetWindowPos().y + 45
            editorWindowSizeX = CImGui.GetWindowSize().x - 6
            editorWindowSizeY = CImGui.GetWindowSize().y - 50
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
        gameInfo = game.editorLoop(update)
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