module StackMan
using SimpleDirectMediaLayer.LibSDL2
include("RenderWindow.jl")
include("Sprite.jl")
        include("Collider.jl")
        include("Entity.jl")
        include("Enums.jl")
        include("Input/Input.jl")
        include("Math/Vector2f.jl")
        include("Rigidbody.jl")
        include("Transform.jl")
        include("Utils.jl")
import Renderer
    function julia_main()
        

        SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
        SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)

        #initializing
        @assert SDL_Init(SDL_INIT_EVERYTHING) == 0 "error initializing SDL: $(unsafe_string(SDL_GetError()))"
        TTF_Init()


        window = Renderer.RenderWindow("GAME v1.0", 1280, 720)
        renderer = window.getRenderer()
        windowRefreshRate = window.getRefreshRate()
        println(windowRefreshRate)
        catTexture = window.loadTexture(joinpath(@__DIR__, "..", "assets", "cat.png"))
        grassTexture = window.loadTexture(joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"))
        input = Input()
        colliders = [
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
            Collider(Vector2f(64, 64), Vector2f(), "none")
        ]
        sprites = [
            Sprite(7, joinpath(@__DIR__, "..", "assets", "images", "SkeletonWalk.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
            ]
        rigidbodies = [
            Rigidbody(1, 0)
        ]

        entities = [
            Entity("player", Transform(Vector2f(0, 100)), sprites[1], colliders[1], rigidbodies[1]) # playerEntity
            Entity("tile0", Transform(Vector2f(0, 650)), sprites[2], colliders[2], C_NULL) 
            Entity("tile1", Transform(Vector2f(64, 650)), sprites[3], colliders[3], C_NULL)
            Entity("tile2", Transform(Vector2f(128, 650)), sprites[4], colliders[4], C_NULL)
            Entity("tile3", Transform(Vector2f(192, 650)), sprites[5], colliders[5], C_NULL)
            Entity("tile4", Transform(Vector2f(256, 650)), sprites[6], colliders[6], C_NULL)
            Entity("tile5", Transform(Vector2f(320, 650)), sprites[7], colliders[7], C_NULL)
            Entity("tile6", Transform(Vector2f(384, 650)), sprites[8], colliders[8], C_NULL)
            Entity("tile7", Transform(Vector2f(448, 650)), sprites[9], colliders[9], C_NULL)
            Entity("tile8", Transform(Vector2f(512, 650)), sprites[10], colliders[10], C_NULL)
            Entity("tile9", Transform(Vector2f(576, 650)), sprites[11], colliders[11], C_NULL)
            Entity("tile10", Transform(Vector2f(640, 650)), sprites[12], colliders[12], C_NULL)
            Entity("tile11", Transform(Vector2f(640, 586)), sprites[13], colliders[13], C_NULL)
            Entity("tile12", Transform(Vector2f(640, 458)), sprites[14], colliders[14], C_NULL)
            Entity("tile13", Transform(Vector2f(0, 586)), sprites[15], colliders[15], C_NULL)
            ]


            
        entities[15].addComponent(Vector2f())
        # playerEntity = Entity(Vector2f(100,100), catTexture)
        w_ref, h_ref = Ref{Cint}(0), Ref{Cint}(0)

        try
            w, h = w_ref[], h_ref[]
            x = entities[1].getTransform().getPosition().x
            y = entities[1].getTransform().getPosition().y
            
            DEBUG = false
            close = false
            speed = 250
            gravity = 500
            timeStep = 0.01
            startTime = 0.0
            totalFrames = 0
            grounded = false
            wasGrounded = false

            #animation vars
            animatedFPS = 12.0
            
            #physics vars
            lastPhysicsTime = SDL_GetTicks()
            
            while !close
                # Start frame timing
                totalFrames += 1
                lastStartTime = startTime
                startTime = SDL_GetPerformanceCounter()
                #region ============= Input
                input.pollInput()
                if input.quit
                    close = true
                end
                
                scan_code = input.scan_code

                if scan_code == SDL_SCANCODE_W || scan_code == SDL_SCANCODE_UP
                    y -= speed / 30
                elseif scan_code == SDL_SCANCODE_A || scan_code == SDL_SCANCODE_LEFT
                    x = -speed
                elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
                    y += speed / 30
                elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
                    x = speed
                elseif gravity == 500 && scan_code == SDL_SCANCODE_SPACE
                    println("space")
                    gravity = -500
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
                elseif keyup == SDL_SCANCODE_SPACE
                    gravity = 500
                end

                input.scan_code = nothing
                input.keyup = nothing
            
                #endregion ============== Input
                    
                #Physics
                currentPhysicsTime = SDL_GetTicks()
                
                grounded = false
                counter = 1
                #Only check the player against other colliders
                for colliderB in colliders
                #TODO: Skip any out of a certain range of the player. This will prevent a bunch of unnecessary collision checks
                    if colliders[1] != colliderB
                        collision = checkCollision(colliders[1], colliderB)
                        transform = colliders[1].getParent().getTransform()
                        if collision[1] == Top::CollisionDirection
                            #Begin to overlap, correct position
                            transform.setPosition(Vector2f(transform.getPosition().x, transform.getPosition().y + collision[2]))
                        elseif collision[1] == Left::CollisionDirection
                            #Begin to overlap, correct position
                            transform.setPosition(Vector2f(transform.getPosition().x + collision[2], transform.getPosition().y))
                            #If player tries to move left here, stop them
                            #x < 0 && (x = 0;) 
                        elseif collision[1] == Right::CollisionDirection
                            #Begin to overlap, correct position
                            transform.setPosition(Vector2f(transform.getPosition().x - collision[2], transform.getPosition().y))
                            #If player tries to move right here, stop them
                            #x > 0 && (x = 0;) 
                        elseif collision[1] == Bottom::CollisionDirection
                            #Begin to overlap, correct position
                            #println("grounded")
                            grounded = true
                            transform.setPosition(Vector2f(transform.getPosition().x, transform.getPosition().y - collision[2]))
                            break
                        elseif collision[1] == Below::ColliderLocation
                            #Remain on top. Resting on collider
                            #println("hit")
                            grounded = true
                        elseif !grounded && counter == length(colliders) && collision[1] != Bottom::CollisionDirection # If we're on the last collider to check and we haven't collided with anything yet
                            #println("not grounded")
                            grounded = false
                        end
                    end
                    counter += 1
                end    

                #println(gravity)
                if grounded && !wasGrounded
                    rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, 0))
                    #println("landed")
                elseif grounded && gravity == -500
                    rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, gravity))
                elseif !grounded
                    rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, gravity == 500 ? gravity : rigidbodies[1].getVelocity().y))
                end
                
                wasGrounded = grounded

                deltaTime = (currentPhysicsTime - lastPhysicsTime) / 1000.0
                #println(deltaTime)
                rigidbodies[1].setVelocity(Vector2f(x, rigidbodies[1].getVelocity().y))

                for rigidbody in rigidbodies
                    position = rigidbody.getParent().getTransform().getPosition()
                    rigidbody.getParent().getTransform().setPosition(Vector2f(round(position.x + rigidbody.velocity.x * deltaTime),round(position.y + rigidbody.velocity.y * deltaTime)))
                end
                        
                lastPhysicsTime =  SDL_GetTicks()
                #Rendering
                currentRenderTime = SDL_GetTicks()
                SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
                window.clear()

                SDL_SetRenderDrawColor(renderer, 0, 255, 0, SDL_ALPHA_OPAQUE)

                for entity in entities
                    entity.update()
                    if DEBUG && entity.collider != C_NULL
                        SDL_RenderDrawLines(renderer, [
                            SDL_Point(entity.getTransform().getPosition().x, entity.getTransform().getPosition().y), 
                            SDL_Point(entity.getTransform().getPosition().x + entity.getCollider().getSize().x, entity.getTransform().getPosition().y),
                            SDL_Point(entity.getTransform().getPosition().x + entity.getCollider().getSize().x, entity.getTransform().getPosition().y + entity.getCollider().getSize().y), 
                            SDL_Point(entity.getTransform().getPosition().x, entity.getTransform().getPosition().y + entity.getCollider().getSize().y), 
                            SDL_Point(entity.getTransform().getPosition().x, entity.getTransform().getPosition().y)], 5)
                    end
                end

                for sprite in sprites
                    deltaTime = (currentRenderTime  - sprite.getLastUpdate()) / 1000.0
                    framesToUpdate = floor(deltaTime / (1.0 / animatedFPS))
                    if framesToUpdate > 0
                        sprite.setLastFrame(sprite.getLastFrame() + framesToUpdate)
                        sprite.setLastFrame(sprite.getLastFrame() % sprite.getFrameCount())
                        sprite.setLastUpdate(currentRenderTime)
                    end
                    sprite.draw(Ref(SDL_Rect(sprite.getLastFrame() * 16,0,16,16)), Ref(SDL_Rect(64,64,64,64)))
                end
                
                if DEBUG
                    # Strings to display
                    window.drawText(string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0))), 20, 0, 0, 255, 0, 24)
                    window.drawText(string("Frame time: ", round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0)), 20, 20, 0, 255, 0, 24)
                end
                


                window.display()
                endTime = SDL_GetPerformanceCounter()
                elapsedMS = (endTime - startTime) / SDL_GetPerformanceFrequency() * 1000.0
                targetFrameTime = 1000/windowRefreshRate

                #x = 0
                if elapsedMS < targetFrameTime
                    SDL_Delay(round(targetFrameTime - elapsedMS))
                end
            end
        finally
            TTF_Quit()
            window.cleanUp()
            SDL_Quit()
        end 
    end
end