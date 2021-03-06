define ['cs!models/DynamicEntity', 'image!/img/character.png'], (DynamicEntity, spriteSheet) ->

    class Character extends DynamicEntity
        frame: 0
        currentAction: 'standRight'
        previousAction: 'standRight'
        actionLock: false
        jumpable: true
        falling: false

        damageBox:
            x: .25
            y: .5

        # Hash which maps actions to their spritemap rows and cells
        actionMap:
            standRight:
                row: 0
                start: 0
                frames: 1
            standLeft:
                row: 0
                start: 1
                frames: 1
            attackRight:
                row: 6
                start: 0
                frames: 5
            attackLeft:
                row: 7
                start: 0
                frames: 5
            runRight:
                row: 1
                start: 0
                frames: 9
            runLeft:
                row: 2
                start: 0
                frames: 9
            jumpRight:
                row: 3
                start: 0
                frames: 6
            jumpLeft:
                row: 4
                start: 0
                frames: 6
            disintegrateRight:
                row: 8
                start: 0
                frames: 5
            disintegrateLeft:
                row: 9
                start: 0
                frames: 5
            clone:
                row: 5
                start: 0
                frames: 4

        template:
            name: 'character'
            fixedRotation: true
            friction: .5
            spriteSheet: true
            image: spriteSheet.src
            imageOffsetX: -.8
            imageOffsetY: -.85
            density:.1
            width: 1
            height: 2.6
            spriteWidth: 96
            spriteHeight: 96
            restitution: 0
            spriteX: 0
            spriteY: 0
            maxVelocityX: 10
            maxVelocityY: 8

        onTick: =>
            @speed = @entity._body.m_linearVelocity.x
            @speedY = @entity._body.m_linearVelocity.y
            # Determines the action method to run for updating the sprite
            actionMethod = 'onTick' + @currentAction[0].toUpperCase() + @currentAction[1..-1]
            @checkJumpability()
            # Update the sprite according to the actionMethod
            @[actionMethod].apply @

        onTickRunRight: =>
            @frame = @frame + @frameAdvanceSpeedX()
            x = @actionMap.runRight.start + Math.floor(@frame) % @actionMap.runRight.frames
            y = @actionMap.runRight.row
            @entity.sprite x, y
            @setAction 'standRight' if @speed is 0

        onTickRunLeft: =>
            @frame = @frame + @frameAdvanceSpeedX()
            x = @actionMap.runRight.start + Math.floor(@frame) % @actionMap.runRight.frames
            y = @actionMap.runLeft.row
            @entity.sprite x, y
            @setAction 'standLeft' if @speed is 0

        onTickStandRight: =>
            x = @actionMap.standRight.start
            y = @actionMap.standRight.row
            @entity.sprite x, y

        onTickStandLeft: =>
            x = @actionMap.standLeft.start
            y = @actionMap.standLeft.row
            @entity.sprite x, y

        onTickJumpRight: =>
            @jumping = true
            frameAdvance = @frameAdvanceJump(@actionMap.jumpRight.frames)
            x = @actionMap.jumpRight.start + frameAdvance
            y = @actionMap.jumpRight.row
            @entity.sprite x, y
            @setAction (if @speedY is 0 then (if @speed isnt 0 then 'runRight' else 'standRight') else 'jumpRight')

        onTickJumpLeft: =>
            @jumping = true
            frameAdvance = @frameAdvanceJump(@actionMap.jumpLeft.frames)
            x = @actionMap.jumpLeft.start + frameAdvance
            y = @actionMap.jumpLeft.row
            @entity.sprite x, y
            @setAction (if @speedY is 0 then (if @speed isnt 0 then 'runLeft' else 'standLeft') else 'jumpLeft')

        onTickAttackRight: =>
            @canvas.trigger 'attack.sound'
            x = @frameAdvanceAttack 'attackRight'
            y = @actionMap.attackRight.row
            @entity.sprite x, y
            target = @findTargets('right')
            if not target.length
                @setAction @previousAction
                @attackFrame = 0
                @unlockCharacter()
                @canvas.trigger 'attack.soundOff'
                return
            if @health? and not @actionLock then @health = @health + target.length
            $(@canvas).trigger 'setHealth', { health: @health }
            @lockCharacter()
            target[0].$wrapper?.setAction 'disintegrate'

        onTickAttackLeft: =>
            @canvas.trigger 'attack.sound'
            x = @frameAdvanceAttack 'attackLeft'
            y = @actionMap.attackLeft.row
            @entity.sprite x, y
            target = @findTargets('left')
            if not target.length
                @setAction @previousAction
                @attackFrame = 0
                @unlockCharacter()
                @canvas.trigger 'attack.soundOff'
                return
            if @health? and not @actionLock then @health = @health + target.length
            $(@canvas).trigger 'setHealth', { health: @health }
            @lockCharacter()
            target[0].$wrapper.setAction 'disintegrate'

        onTickDisintegrate: =>
            @lockCharacter()
            dir = (if @previousAction.match /left/i then 'disintegrateLeft' else 'disintegrateRight')
            y = @actionMap[dir].row
            x = @frame
            if x >= (@actionMap[dir].start + @actionMap[dir].frames)
                @destroy()
            @entity.sprite x, y
            @frame = @frame + 1

        onTickClone: =>
            @lockCharacter()
            y = @actionMap.clone.row
            x = @frame % @actionMap.clone.frames
            @entity.sprite x, y
            @frame = @frame + 1

            if @frame > 10
                @createClone()
                @unlockCharacter()
                if @health? then @health = @health - 1
                $(@canvas).trigger 'setHealth', { health: @health }
                @setAction @previousAction

        onImpact: =>
            @stopJumping()

        lockCharacter: =>
            @actionLock = true
            @clearMovement()

        unlockCharacter: =>
            @actionLock = false

        checkJumpability: =>
            speedY = @entity._body.m_linearVelocity.y
            @jumpable = Math.abs(speedY) < .01

        clearMovement: =>
            @entity.clearForce 'movement'
            @entity.friction .5

        stopJumping: =>
            return unless @falling is true and @jumping is true
            @jumping = false
            if @currentAction.match /jump/i then @clearMovement()
            if @currentAction is 'jumpRight' then @setAction 'standRight'
            if @currentAction is 'jumpLeft' then @setAction 'standLeft'

        setAction: (action) =>
            if action is @currentAction or @actionLock then return
            @previousAction = @currentAction
            @currentAction = action
            @frame = 0

        frameAdvanceSpeedX: =>
            # Determine amount to add to frame based on movement speed
            frameAdvance = Math.abs(@speed) / @maxVelocityX
            frameAdvance = Math.max frameAdvance, .25
            frameAdvance = Math.min frameAdvance, 1

        frameAdvanceJump: (totalFrames) =>
            # Determine which frame we're at based on the vertical speed
            percent = Math.abs(@speedY / @maxVelocityY) * 100
            mid = Math.floor(totalFrames / 2)
            frameAdvance = (if @speedY < 0 then 0 else mid)
            if @speedY < 0
                frameAdvance = @frame
                if @frame < 2
                    @frame = @frame + 1
                @falling = false
            else
                if percent > 10 then frameAdvance = frameAdvance + 1
                if percent > 30 then frameAdvance = frameAdvance + 1
                @falling = true

            frameAdvance

        frameAdvanceAttack: (direction) =>
            if not @attackFrame? then @attackFrame = @actionMap[direction].start
            @attackFrame = @attackFrame + 1
            if @attackFrame >= (@actionMap[direction].start + @actionMap[direction].frames)
                @attackFrame = 2
            @attackFrame

        findTargets: (direction) =>
            pos = @entity.position()
            x1 = x2 = 0
            if direction is 'left'
                x1 = pos.x - @damageBox.x
                x2 = pos.x
            else
                x1 = pos.x + @template.width
                x2 = x1 + @damageBox.x
            y1 = pos.y
            y2 = y1 + @damageBox.y
            potentials = @world.find x1, y1, x2, y2
            potentials = potentials.filter (target) -> target._name is 'character'
            potentials

    return Character