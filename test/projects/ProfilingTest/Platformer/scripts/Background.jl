module BackgroundModule
    function conditional_using(pkg::Symbol)
        if !haskey(Base.loaded_modules, pkg)
            @eval using $(pkg)
        end
    end
    conditional_using(:JulGame)

    mutable struct Background
        parent

        function Background()
            this = new()

            this.parent = C_NULL

            return this
        end
    end

    function JulGame.initialize(this::Background)
    end

    function JulGame.update(this::Background, deltaTime)
        this.parent.transform.position = JulGame.Math.Vector2f(MAIN.scene.camera.position.x + 9.5, 0)
    end

    function JulGame.on_shutdown(this::Background)
    end
end # module