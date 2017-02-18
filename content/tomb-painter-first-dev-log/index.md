---
title: Tomb Painter. The first dev log (2017-2018)
date: 2019-01-06T23:22:00+03:00
tags: [Tomb Painter, dev log, C++, Lua, game dev]
draft: false
---

---


Hello, everyone. Today I'm ready to officially announce and talk about the game I'm currently working on!

{{< figure src="tomb-painter-logo.png" >}}

It's called Tomb Painter and I've been working on it since August of 2017.

{{< figure src="characters.png" >}}

In the game, a painter arrives on mysterious island, which has strange things going on with it. Blob-shaped monsters made of paint start to appear from an ancient tomb. The only way to stop this is to paint beautiful patterns which were washed away by a flood that happened some time ago.

The main mechanic is that you can draw on floors and paint stuff by hitting it with your brush. By painting on the floor, you solve different puzzles.

{{< video width="480px" label="gameplay" mp4="gameplay.mp4" >}}

{{< toc >}}

## Start of development

I've started to work on this game, because developing [Re:creation](https://eliasdaler.github.io/re-creation/) became too hard for me. It had gigantic scope and pretty detailed art, which took a long time to produce, so I've decided to make something simpler as my first game.

It all started with this prototype art, which was highly inspired by [Minit](http://minitgame.com/):

{{< figure src="tomb-painter-first-prototype.png" >}}

I was pretty surprised that so much can be accomplished with only two colors, but I wanted a bit more detail, so I've decided to use 4 colors, just like Game Boy did:

{{< figure src="tomb-painter-early.png" >}}

{{< figure src="early-gameplay.gif" >}}


The game's internal resolution is 160x144 pixels, same as Game Boy again. I've decided not to follow all limitations of Game Boy, as it would be pretty hard to make a good looking game with them, but still, 4 colors and 160x144 is pretty limiting, while it can also look good. It also takes a lot less time to produce art.

I've also experimented with adding a second palette (just like Super Game Boy on SNES did) and it looked pretty interesting:

{{< figure src="early-gameplay2.gif" >}}

You can also see first painting system which was improved later.

So now I have two palettes with 4 colors each. The game is rendered in shades of grey and I can easily map each shade to whatever color I want to get different palettes, including the original Game Boy one:

{{< figure src="gameboy.png" >}}

I also made some simple shaders for fade in and fade out:

{{< video width="480px" label="fades" mp4="fadein-fadeout.mp4" >}}

and for lighting simulation:

{{< video width="480px" label="light" mp4="light.mp4" >}}

It's still 4 colors, but it looks pretty nice.

A lot of time was spent on making paint look and feel good. Note that the tiles of paint change depending on direction you're painting in, so it looks like a continuous trail, and you can also have multiples layer of paint. The paint also changes the color of what's below it and that was pretty interesting to implement too. I may write about all that shader magic in the future.

{{< figure src="painting.gif" >}}

As for more technical details: I've used Re:creation's engine and started to modify it as I needed. I had working prototype of Tomb Painter in two weeks and it felt good to not start from scratch. All the abstractions and worries about design were worth it!

I've improved the engine quite a lot and if I start to go over it all in detail, so I'll make a short summary here, and if you want to have it explained in depth, ask about stuff you want to be covered in comments!

## Game / engine separation

Right now I'm still working on better game / engine separation, but basically the engine is now a statically linked library. I've decided to call the engine **EDGE** (Elias Daler's Game Engine). The "game" part is just several .cpp files and mostly just Lua code, because I prefer to code game logic in it. Once I feel that engine is decoupled enough and I have some time to make a simple game with it, I plan to open source the engine part!

## CMake / FetchContent / Third party dependencies

I've learned a lot about CMake (thanks to [Professional CMake book](https://crascit.com/professional-cmake/)) and finally achieved a perfect setup for me. I've managed to get all third party dependencies (9 of them) to be fetched at configure time. Then, I build all the dependencies and my game. It works perfectly - it's easy to start with a clean folder and just build everything!
It's also very easy to update to new versions of the libraries, here's the only thing I need to do:

{{< figure src="changing-lib-versions.png" >}}

## Cutscene system

I've written an article about how I write cutscenes with coroutines [here](https://eliasdaler.github.io/how-to-implement-action-sequences-and-cutscenes/). It's pretty great! A lot of code was simplified and now I can easily write complex action sequences, multi-branch cutscenes and dialogue trees with it. So, with the code like this:

```lua
local answer = girl:say('do_you_love_lua',
                          { 'YES', 'NO' })
if answer == 'YES' then
  girl:setMood('happy')
  girl:say('happy_response')
else
  girl:setMood('angry')
  girl:say('angry_response')
end
```
I get this:

{{< figure src="dialogue.gif" >}}

## Quest and saving system

It's now possible to have a main quest line in the game, but also side quests with multiple states which are easy to write, modify and read.

Previously, Re:creation had a very simple save system which saved your inventory, main quest progression, etc. But I've decided that I needed something more complex for Tomb Painter, to store consequences of NPC interactions or side quest progression. The current system tracks game's state in real time and saves all important stuff in a Lua table once it happens (by catching events). Then, when you save, this table is just converted to JSON and saved to a file. Pretty awesome!

## Replay system

I've also implemented a replay system which lets me record all input and then replay it in any speed I want. I can record minutes of gameplay and then run it very fast! I can also use it to quickly repeat some tasks (e.g. kill two enemies than go to room X) and then continue playing the game.

## Data / script separation

Previously, I've stored all information about prefabs in Lua scripts. But then I've decided that they'd look better in JSON and it'll be much easier to write a GUI tool for modifying prefabs in the future. Here's an example of how prefab looks:

```json
"slime" : {
    "ai" : {
        "type" : "chaser",
        "viewRadius" : 60,
        "viewAngle" : 90
    },
    "animation" : { },
    "collision" : { "boundingBox" : [ 6, 4 ] },
    "damage" : {
        "amount" : 1,
        "type" : "physical"
    },
    "graphics" : {
        "spriteOrigin" : [ 8, 10 ],
        "overlays" : {
            "paint" : "slime_overlay"
        }
    },
    "health" : { "maxHealth" : 2 },
    "movement" : {
        "moveSpeed" : [ 15.0, 15.0 ],
        "mass" : 0.5
    },
    "sound" : {
        "sounds" : {
            "hit" : { "file" : "enemy_hit" },
            "die" : { "file" : "enemy_die" }
        }
    },
    "stateMachine" : {
        "main" : {
            "initialState" : "IdleState",
            "transitionTable" : "hero"
        },
        "ai" : {
            "initialState" : "AIPatrolState",
            "transitionTable" : "ai_slime"
        }
    }
}
```

As you can see, it's easy to read. Transition tables are still written in Lua, because they usually have conditions inside of them and they look like this:

```lua
{
    IdleState = {
        update = function(entity)
            if not entity:getVelocity():isZero() then
                return "MoveState"
            end
        end
    },
    MoveState = {
        update = function(entity)
            if entity:getVelocity():isZero() then
                return "IdleState"
            end
        end
    },
    DyingState = {
        [EventType.AnimationFinished] = {
            callback = function(entity, event)
                if event.data.animationName == "dying" then
                    return "DiedState"
                end
            end
        }
    },
    ...
}
```

Update fuction can either call `setState` explicitly, or just return a name of the state to transition into. Another way to transition is by catching the event. So, if entity is in `DyingState` and it catches `AnimationFinished` event, the callback is called where it can then transition into another state.

## Other

All GUI widgets are now entities, which is very useful as they can be manipulated as normal game objects and I don't have any repeating rendering/movement code.

Also, I've worked a lot on resource and entity prefab management. Now, entity prefabs are ref counted and if entity prefab is unused on another level, it's unloaded with all resources which it was using (unless other prefabs use it too). The system is very complex to explain in a few paragraphs and I might write an article about it later.

And there was a lot of refactoring, of course. All the code is now in its best condition ever.

## What's next?

{{< figure src="shadows.png" >}}

Right now, my next goal is making game look even prettier shadows (see the screenshot above), animated tiles, a new level, the first boss and the first awesome mini-game. Overall, the progress looks very good and I'm very happy with my engine and I can't wait to start working on the game again. I'll also have a lot more time to work on the game (find out why in the next post!), so it's going to be awesome.

See you soon! Thanks for reading.

