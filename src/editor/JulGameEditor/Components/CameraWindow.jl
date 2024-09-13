mutable struct CameraWindow 
    open::Bool
    camera

    function CameraWindow(open::Bool = true, camera = nothing)
        new(open, camera)
    end
end

function show_camera_window(this::CameraWindow)
    
    @cstatic begin
        #region Scene List
        CImGui.Begin("Camera") 
        
            if this.camera === nothing || !this.open
                CImGui.Text("Open a scene to view the camera settings.")
                return
            end
            CImGui.Text("Background color: $(this.camera.backgroundColor[1]), $(this.camera.backgroundColor[2]), $(this.camera.backgroundColor[3])")
            # create inputs for the camera properties
            
            CImGui.Text("Offset: $(this.camera.offset.x), $(this.camera.offset.y)")

            max_width = 100.0  # Adjust the width as needed
            CImGui.PushItemWidth(max_width)

            # Temporary Float32 storage
            offset_x32 = Cfloat(this.camera.offset.x)
            offset_y32 = Float32(this.camera.offset.y)
            
                
            # Update using ImGui InputFloat
            isEdited = @c CImGui.InputFloat("Offset X", &offset_x32, 1)
            if isEdited
                println("Offset X changed to: ", offset_x32)
                this.camera.offset = Vector2f(Float64(offset_x32), this.camera.offset.y)
            end
            CImGui.SameLine()
            isEdited = @c CImGui.InputFloat("Offset Y", &offset_y32, 1)
            if isEdited
                this.camera.offset = Vector2f(this.camera.offset.x, Float64(offset_y32))
            end
            
            CImGui.Text("Position: $(this.camera.position.x), $(this.camera.position.y)")
            
            # Temporary Float32 storage
            position_x32 = Float32(this.camera.position.x)
            position_y32 = Float32(this.camera.position.y)
            isEdited = @c CImGui.InputFloat("Position X", &position_x32, 1)
            if isEdited
                this.camera.position = Vector2f(Float64(position_x32), this.camera.position.y)
            end
            CImGui.SameLine()
            isEdited = @c CImGui.InputFloat("Position Y", &position_y32, 1)
            if isEdited
                this.camera.position = Vector2f(this.camera.position.x, Float64(position_y32))
            end
            
            CImGui.Text("Size: $(this.camera.size.x), $(this.camera.size.y)")
            
            # Temporary Float32 storage
            size_x32 = Float32(this.camera.size.x)
            size_y32 = Float32(this.camera.size.y)
            isEdited = @c CImGui.InputFloat("Size X", &size_x32, 1)
            if isEdited
                this.camera.size = Vector2(Float64(size_x32), this.camera.size.y)
            end
            CImGui.SameLine()
            isEdited = @c CImGui.InputFloat("Size Y", &size_y32, 1)
            if isEdited
                this.camera.size = Vector2(this.camera.size.x, Float64(size_y32))
            end
            
            CImGui.Text("Starting Coordinates: $(this.camera.startingCoordinates.x), $(this.camera.startingCoordinates.y)")
            
            # Temporary Float32 storage
            start_x32 = Float32(this.camera.startingCoordinates.x)
            start_y32 = Float32(this.camera.startingCoordinates.y)
            isEdited = @c CImGui.InputFloat("Starting Coordinates X", &start_x32, 1)
            if isEdited
                this.camera.startingCoordinates = Vector2f(Float64(start_x32), this.camera.startingCoordinates.y)
            end
            CImGui.SameLine()
            isEdited = @c CImGui.InputFloat("Starting Coordinates Y", &start_y32, 1)
            if isEdited
                this.camera.startingCoordinates = Vector2f(this.camera.startingCoordinates.x, Float64(start_y32))
            end
            
            CImGui.PopItemWidth()
        CImGui.End()
    end
end
