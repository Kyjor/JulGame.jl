using JulGame.MainLoop # Accessed by MAIN

mutable struct ExampleScript # The name of the script in the editor must match this
    parent # MUST INCLUDE THIS, Later accessed by this.parent

    function ExampleScript()
        this = new() # MUST INCLUDE THIS
        
        this.parent = C_NULL # MUST INIT THIS

        return this # MUST INCLUDE THIS
    end
end

function Base.getproperty(this::ExampleScript, s::Symbol) # MUST INCLUDE THIS to be able to write methods
    if s == :initialize # Runs once at the start
        function()
            MAIN.cameraBackgroundColor = [252, 235, 205] # Example: Sets the background color of the camera
        end
    elseif s == :update # Runs every frame
        function(deltaTime)
        end
    elseif s == :setParent # MUST INCLUDE THIS
        function(parent)
            this.parent = parent # MUST INCLUDE THIS, you can add other stuff below
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end