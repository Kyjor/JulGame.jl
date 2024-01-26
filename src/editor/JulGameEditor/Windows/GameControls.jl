function LoadScene(scenePath, renderer)
    game = C_NULL
    try
        game = SceneLoaderModule.LoadSceneFromEditor(scenePath, renderer, true);
    catch e
        rethrow(e)
    end

    return game
end

function ShowGameControls()
    @cstatic begin
        CImGui.Begin("Controls")  
            CImGui.Text("Pan scene: Arrow keys/Hold middle mouse button and move mouse")
            CImGui.NewLine()
            CImGui.Text("Zoom in/out: Hold spacebar and left and right arrow keys")
            CImGui.NewLine()
            CImGui.Text("Select entity: Click on entity in scene window or in hierarchy window")
            CImGui.NewLine()
            CImGui.Text("Move entity: Hold left mouse button and drag entity")
            CImGui.NewLine()
            CImGui.Text("Duplicate entity: Select entity and click 'Duplicate' in hierarchy window or press 'LCTRL+D' keys")
            CImGui.NewLine()
        CImGui.End()
    end
end