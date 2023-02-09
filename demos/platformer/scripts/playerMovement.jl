include("../../../src/Math/Vector2f.jl")

mutable struct PlayerMovement
    input
    parent

    function PlayerMovement()
        this = new()
        
        this.input = C_NULL
        this.parent = C_NULL
        this.initialize()

        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function()
           # this.parent.getRigidbody().setVelocity(Vector2f())
            scan_code = this.input.scan_code
            if scan_code == SDL_SCANCODE_W || scan_code == SDL_SCANCODE_UP
                y -= speed / 30
            elseif scan_code == SDL_SCANCODE_A || scan_code == SDL_SCANCODE_LEFT
                x = -speed
                if isFacingRight
                    isFacingRight = false
                    flipPlayer = true
                end
            elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
                y += speed / 30
            elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
                x = speed
                if !isFacingRight
                    isFacingRight = true
                    flipPlayer = true
                end
            elseif scan_code == SDL_SCANCODE_F3 
                println("debug toggled")
                DEBUG = !DEBUG
            else
                #nothing
            end
    
            keyup = input.keyup
            if keyup == SDL_SCANCODE_W || keyup == SDL_SCANCODE_UP
                #y -= speed / 30
            elseif x == -speed && (keyup == SDL_SCANCODE_A || keyup == SDL_SCANCODE_LEFT)            
                x = 0
            elseif keyup == SDL_SCANCODE_S || keyup == SDL_SCANCODE_DOWN
                # y += speed / 30
            elseif x == speed && (keyup == SDL_SCANCODE_D || keyup == SDL_SCANCODE_RIGHT)
                x = 0
            end
    
            input.scan_code = nothing
            input.keyup = nothing
           
            this.parent.getRigidbody().setVelocity(Vector2f(x, rigidbodies[1].getVelocity().y))

        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :setInput
        function(input)
            this.input = input
        end
    else
        getfield(this, s)
    end
end