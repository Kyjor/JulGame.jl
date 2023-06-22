using JulGame.MainLoop

mutable struct Dialogue
    charTimer::Float64
    currentMessage::String
    currentMessageIndex::Int64
    currentPositionInMessage::Int64
    gameManager
    isNormalDialogue::Bool
    isPaused::Bool
    isReadingMessage::Bool
    isQueueingNextMessage::Bool
    messages::Array{String}
    messageTimer::Float64
    parent
    playerMovement
    timeBetweenCharacters::Float64
    timeBetweenMessages::Float64


    function Dialogue(messages::Array{String}, timeBetweenCharacters::Float64, timeBetweenMessages::Float64, gameManager, playerMovement)
        this = new()
        
        this.charTimer = 0.0
        this.currentMessage = messages[1]
        this.currentMessageIndex = 1
        this.currentPositionInMessage = 1
        this.gameManager = gameManager
        this.isNormalDialogue = true
        this.isPaused = false
        this.isReadingMessage = false
        this.isQueueingNextMessage = true
        this.messages = messages
        this.messageTimer = 0.0
        this.playerMovement = playerMovement
        this.timeBetweenCharacters = timeBetweenCharacters
        this.timeBetweenMessages = timeBetweenMessages

        return this
    end
end

function Base.getproperty(this::Dialogue, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function(deltaTime)
            if this.isPaused
                return
            end
            if this.messageTimer > this.timeBetweenMessages
                this.isQueueingNextMessage = false
                this.isReadingMessage = true
                this.messageTimer = 0.0
                this.isNormalDialogue ? MAIN.scene.textBoxes[1].updateText(" ") : MAIN.scene.textBoxes[2].updateText(" ")
            end
            if this.isQueueingNextMessage == true
                this.messageTimer = this.messageTimer + deltaTime
                return
            end

            this.charTimer = this.charTimer + deltaTime
            if !this.isReadingMessage || this.charTimer < this.timeBetweenCharacters
                return
            end
            #if at end, set isReadingMessage to false
            if this.currentPositionInMessage == length(this.currentMessage)+1
                if this.currentMessageIndex == length(this.messages) 
                    if this.isNormalDialogue
                        MAIN.scene.colliders[2].enabled = false
                        this.playerMovement.canMove = true
                    else
                        MAIN.scene.textBoxes[1].text = " "
                    end
                    this.isPaused = true
                    return
                end
                this.isReadingMessage = false
                this.isQueueingNextMessage = true
                this.currentPositionInMessage = 1
                
                this.charTimer = 0.0
                if this.isNormalDialogue
                    if this.currentMessageIndex == 3 
                    MAIN.scene.sounds[4].toggleSound()
                    elseif this.currentMessageIndex == 12
                        MAIN.scene.sounds[3].toggleSound()
                        this.isPaused = true
                        #set up money blocks
                        for moneyBlock in this.gameManager.moneyBlocks
                            moneyBlock.isActive = true
                        end
                        this.gameManager.goldPot.isActive = true
                    elseif this.currentMessageIndex == 13
                        MAIN.scene.sounds[5].toggleSound()
                    elseif this.currentMessageIndex == 17 
                        MAIN.scene.sounds[3].toggleSound()
                        this.isPaused = true
                        for platform in this.gameManager.platforms
                            platform.isActive = true
                        end    
                    elseif this.currentMessageIndex == 19
                        MAIN.scene.sounds[6].toggleSound()
                    elseif this.currentMessageIndex == 23
                        MAIN.scene.sounds[3].toggleSound()
                        this.playerMovement.parent.getTransform().position = Vector2f(0.0, 9.0)
                        MAIN.scene.entities[15].isActive = false
                        MAIN.scene.entities[16].isActive = false
                    elseif this.currentMessageIndex == 26
                        this.playerMovement.canMove = true
                        this.isPaused = true
                    elseif this.currentMessageIndex == 27
                        MAIN.scene.sounds[5].toggleSound()
                    elseif this.currentMessageIndex == 30
                        MAIN.scene.sounds[7].toggleSound()
                    end
                end
                this.currentMessageIndex = this.currentMessageIndex + 1
                this.currentMessage = this.messages[this.currentMessageIndex]

                return
            end
            if this.isNormalDialogue
                MAIN.scene.textBoxes[1].updateText(string(MAIN.scene.textBoxes[1].text == " " ? "" : MAIN.scene.textBoxes[1].text, this.currentMessage[this.currentPositionInMessage]))
            else
                MAIN.scene.textBoxes[2].updateText(string(MAIN.scene.textBoxes[2].text == " " ? "" : MAIN.scene.textBoxes[2].text, this.currentMessage[this.currentPositionInMessage]))
            end
            # add next character to text box 
            # play a sound 
            MAIN.scene.sounds[2].toggleSound()

            this.currentPositionInMessage = this.currentPositionInMessage + 1
            this.charTimer = 0.0
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end