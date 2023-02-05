---
title: "Re:creation dev log. December 2016 - March 2017."
date: 2017-04-19T23:00:00+03:00
draft: false
---

No posts in four months! And I haven't worked on the game for the last one and a half. Is the project dead? No! Let's pretend that nothing happened and I'll show what I did since December and will tell about my future plans in the end.


{{< video width="480px" label="Child-parent example" mp4="child-parent.mp4" >}}

{{< toc >}}

## Lots of work! Moving everything to Lua

I moved a lot of code to Lua! For quite some time I thought that this didn't make much sense or was very difficult, but turns out it's easier as the more and more code gets moved to Lua. Here's a comparison of lines of code between two dates.

**27.11.2016**

|Language|files|blank|comment|code|
|---|---|---|---|---|
|C++|103|2420|533|13073|
|Lua|116|510|154|5071|
|C/C++ header|123|1386|158|4315|

**22.02.2017**

|Language|files|blank|comment|code|
|-------|----|----|------|---|
|C++|109|1938|330|10590|
|Lua|127|706|135|5167|
|C/C++ header|133|1296|90|4014|

Note, that even though I've added a lot of new code, the resulting code is still smaller. And Lua code became larger just by 100 lines, even though I moved a lot of C++ code here! This may also look as a little work was done, but `git diff` between commits made in December and March results in this:

```sh
460 files changed, 14486 insertions(+), 16035 deletions(-)
```

That's a lot of changes!

All game-specific components are now in Lua. For example, inventory, health components and others can be implemented in Lua efficiently because I don't have to iterate them in tight loops in every frame. They're mostly used for some basic logic and data storage. Only the following components are implemented in C++ now: Transform, Hierarchy, Graphics, Movement, Sound. As you can see, these components are pretty low-level and are mostly not tied to my game at all, which is great.
Here's an example of a game specific component defined in Lua:

```lua
-- ItemComponent.lua
local Component = require("Component")
local ItemComponent = Component:subclass("ItemComponent")

function ItemComponent:initialize()
    Component:initialize()
    self.value = 0
end

function ItemComponent:loadData(data)
    if data.value then
        self.value = data.value
    end
    self.name = data.name
    self.description = self.description
    self.iconName = data.iconName

    self.onEquipFunc = data.onEquip
    self.onUnequipFunc = data.onUnequip
    self.useFunc = data.use
end

function ItemComponent:use(itemOwner)
    if self.useFunc then
        self:useFunc(itemOwner)
    end
end

function ItemComponent:onEquip(itemOwner)
    if self.onEquipFunc then
        self:onEquipFunc(itemOwner)
    end
end

function ItemComponent:onUnequip(itemOwner)
    if self.onUnequipFunc then
        self:onUnequipFunc(itemOwner)
    end
end

function ItemComponent:getIconName()
    return self.iconName
end

return ItemComponent
```

I also moved all of GUI logic to Lua too. The most complex GUI is dialogue GUI. It does a lot of stuff: it displays text character by character, speaking entity's portrait; highlights some words, handles player's choice in dialogues. I didn't think that moving it to Lua would be real as the logic was pretty complex... but I managed to do it! Here's a reminder of how many things happen in dialogues:

{{< video width="480px" label="Dialogue example" mp4="dialogue-cat.mp4" >}}

Now `GuiState` in C++ just iterates over all GUIs in GUI stack and just calls update and draw functions, not caring about game-specific things. Oh yeah, I now have GUI stack, so I can implement complex GUI's which stack on top of each other (e.g. pause screen GUI on top of game GUI)

By moving some components and all GUI stuff to Lua I finished a pretty important thing: all the game logic is in Lua now! Absolutely everything! This makes me incredibly happy and lets me easily implement new things without caring how Lua and C++ will interact. And another great thing is that the code is now easier to read and it 2-3 times smaller!

I also implemented game mode stack in Lua, which was previously handled in C++. This means that I can easily create new game modes without touching any C++ code.

This makes my engine a lot more generic and separates it from the game, which is great. This means that I can easily reuse my engine in other projects later: I'll just have to change scripts and resources and most of the C++ code will remain the same. I will probably explain my current engine structure a bit later, once I'm 100% confident that it works great.

## GUI

Let's talk about GUI a bit more. First of all, now there's a good parent-child relation between elements. I store child offset relative to parent, so I can easily group and move things together. For example, a portrait of talker is a child of a dialogue window and its relative position to the border of the window is (6,8). So if I render the dialogue window at (100, 200), I'll render the dialogue portait at (106, 208) by combining local child's transform and parent's transform.

I also implemented nine-patch windows. Previously I just stored a big sprites of windows, but now I can just store them like this:

{{< figure src="gui-nine-patch.png" title="Nine-patch texture" >}}

and with some texture repeating, flipping and mirroring, I can get the dialogue window!
{{< figure src="dialogue-window.png" title="Resulting dialogue box" >}}
This not only saves texture space, but also allows me to easily create windows of different sizes.

## Some small C++ related refactorings

* Added lots of `const` where possible. The game was const correct most of the time, but there are quite a few places where I made non-const local variables which don't change or failed to make some member function const, which they later became with some effort. Turns out that most of the time the things stay constant and very few things change, that's why having most of the stuff const is great: you can easily see things that **do** change.
* Stopped passing pointers in most functions and now pass everything by reference unless the pointer is really needed. A lot of this was in very old code, when I didn't realize how perfect references are.
* Started using `std::reference_wrapper` instead of raw non-owning pointers for storing references to stuff in `std::vector`. This is a very useful indicator of "hey, this is just a reference!"
* Stopped handling each axis separately in some places, making changes like this:

```cpp
someX = otherX + 5;
someY = otherY + 10;
```

and now I do this instead:

```cpp
someVector += otherVector + sf::Vector2f(5, 10);
```

I used a lot of vectors before, but there were still places where I did computations for each vector's coordinate or stored coordinates in two variables. It was pretty dumb, because most of the time you do the same thing for both X and Y, and duplicating the same code is not smart.

* Introduced lots of type aliases, for example `TileIndex` instead of `sf::Vector2i`, `ComponentList` instead of `std::vector<std::reference_wrapper<Component>>` and so on (wish there were strong typedefs in C++!). This made code much more readable, because it leaves you with less information and most of the time I just don't care about the underlying type, I care about it's meaning.


## Levels and tile maps

A huge effort was put into remaking tile map system. Previously each tile map was a grid of chunks (each 8x8 tiles in size). This allowed me to save some space by not having to store a lot of empty tiles. But the data structure was pretty complicated. I used `std::vector<std::vector<TilemapChunk>>` and so if some chunks were stored in negative coordinates, I had to store index of top-left chunk and make sure to keep it in mind when accessing other chunks, because I couldn't store negative indices in `std::vector<std::vector<TilemapChunk>>`. So, if `minChunkIndex` was (-10, -20), I found real index of (-3, -4) chunk in vector of vectors by removing `minChunkIndex`: (-3, -4) - (-10, -20) = (7, 16)

It wasn't very good system for various reasons, so I implemented a simpler structure: `std::unordered_map<ChunkIndex, LevelChunk>` (`ChunkIndex` is `sf::Vector2i`). Now I don't have to store `minChunkIndex` and formulas are simplified. I also don't waste space on empty chunks, which is another advantage of new system. It's similar to implementing sparse matrices: instead of having large 2D array, I only store elements which are not zero (not empty in case of tile chunks).

I also improved a lot of level editor code by completely removing all duplication, encapsulation breaks, etc. I previously thought like this:"It's just a development tool, it doesn't have to have very good code!", but turns out that code here matters very much too! First of all, duplication is always bad. Secondly, encapsulation breaks make changes to other classes much harder.

Thankfully, there weren't much such breaks and I actually made a post previously about how having `TileMap::setTile` function saved me a lot of time, as I could easily change data structures of level without having to modify level editor code. But there were still some places in which I had to access some private parts of `TileMap`. So I made a lot of getters and setters. And it made `TileMap` class not properly encapsulated and much longer than it needed to be. So I found a great alternative.

[Attorney-Client pattern](https://en.wikibooks.org/wiki/More_C%2B%2B_Idioms/Friendship_and_the_Attorney-Client) is a great way of solving this problem. Basically, I let some encapsulation breaks by creating LevelModifier structure and making it a friend of TileMap and other level related classes. Now if I need to create an encapsulation breaking function, I create something like this:

```cpp
void LevelModifier::setTile(Tilemap& tilemap, /* other args */)
{
    ... // can access private data members and member functions of TileMap
}
```

This function is static, so I can later call it in LevelEditor like this:

```cpp
if (/* left mouse button clicked */) {
    LevelModifier::setTile(tileMap, selectedTile);
}
```

Awesome. In fact, the number of such encapsulation functions is just 10. Pretty low and easily controllable. If I find myself in a situation where I had to change TileMap class considerably, I'll be confident that I'll have to deal with breaking changes in just a few functions.

After this experience, I wondered how many functions of other classes I can make private. Previously I made them public by default for some reason, even if they were only called in member functions of this class. I managed to make quite a lot functions private without making significant changes to any code and improved encapsulation by doing so. There's a small advantage to it: I can be sure that changing private function of the class won't need many changes in other places.

Back to levels. Previously all entity positions were stored in a level file and during level loading I just created each entity and placed them in the right spots of the map. This made some things pretty hard to load/save. I had to store position where entity spawned, I had to know if some entity will be saved to level file or not, etc.

But then I realized one simple thing: what I considered "entity info" in level files was actually "spawn points info". So if I just stored info about spawn points in tile map, I could then easily spawn entities with them later and also change them in level editor, instead of working with concrete entity instances. So, when I move entity in level editor, I don't just move instance of this entity, but also its corresponding spawn point.

It's just separation of concerns. Entity doesn't have to know about it's spawn point most of the time. And when I save level, I don't care about particular entities, I just care about spawn points. I can iterate through them and just save their properties. Restoring initial level state is also easier: I can just remove all entities and spawn new ones using spawn points.

Trying to restore each entity's initial state is more error prone. I guess this method of doing things explains bugs with saves in some games. In Fallout: New Vegas some NPCs may become hostile and attack you because of your actions, and after you reload your save, they may still attack you, even though in the loaded save state they were neutral to you! Probably this is explained by a bug when restoring entity's state, if you reload the game, the game works as usual.

I also started storing tile maps in JSON. Previously I stored them in a custom plain text format, but as the format got progressively harder to maintain (lots of parsing/saving code), I remade the whole thing in JSON. The code is much simpler to read and expand, so it's great!

Another thing I made is ability to hold mouse button down and paint tiles. Yes, this seems like a very easy thing to implement, but it wasn't! I had to make sure that I could properly undo this action, create new level chunks on the fly, etc. And now I can easily create maps in any direction with this feature.

## Child-parent hierarchy and relative transforms

Okay, if I made a more complex game, I would have made this a lot earlier, but here we go. Look at the gif:

{{< figure src="child-parent.gif" title="Child-parent example" >}}

Hat entity is a child of Renatus entity. Renatus is a child of moving platform entity. This simple hierarchy is easy to handle: the only thing that moves is a platform. It stores coordinate of Renatus relative to it and uses it for relative movement. As Renatus gets moved, the hat moves by the same offset as well. The system is very easy, I just traverse through hierarchy and apply the same movement delta to each entity.

One small thing had given me lots of headache: sometimes the relative movement was a bit shaky. It was because of float rounding, the picture explains the problem:
![Floor problem](/assets/re_creation_dev_log_dec_march/floor_problem.png)
{{< figure src="floor-problem.png" >}}
In the example both entities move by 0.2 pixels, but due to rounding on the screen, you can see a gap between the two appearing. This was unacceptable!

Check out the [thread I made about this](https://en.sfml-dev.org/forums/index.php?topic=21626), if you're interested in my solution. There were some interesting points made in the thread as well.

## Other small things

And here are some other small things which I don't want to write about, but if you're interested in some, feel free to ask about them!

* Previously all side animations had copies in a sprite sheet (e.g. left and right walking animations). Now I just flip them on GPU by setting texture rect's width to be negative, when I want to flip animation. I'll be doing the same with mirrored/rotated tiles a bit later.
* Stupid collision optimization: I stopped checking collisions between static entities. There's no need to check if static, unmovable tree collides with house or not. Both entities can't move The number of collision checks reduced greatly in the result and collision is very fast now.
* Started using entity handles (see [Making and storing references to game objects (entities) in C++ and Lua]({{< ref "/game-object-references" >}}).
* Camera is an entity now. Of course, it has properties of an entity: transform, movement component, AI component (used for following the path). So I don't have to rewrite the same code twice and can script all camera logic in Lua.
* Started using seconds instead of milliseconds everywhere. `sf::Time::asSeconds` returns a `float`, while `sf::Time::asMilliseconds` returns a rounded `int` (usually 16, corresponding to 60 FPS), the results are terrible for pixel perfect games, especially during camera scrolling. It results in camera having non-smooth movement, which has been a problem I was trying to fix for ages and finally did with such a simple change. Here's [a post about the similar problem which FEZ apparently also had](https://plus.google.com/+flibitijibibo/posts/PysMth9Y5kN) which inspired me to do this.
* Made some multi-threading during loading. Basically, I can do most of the loading in another thread: sounds, scripts, level data, etc. But not textures, because OpenGL is not multi-threaded. The solution is simple: I load textures in RAM first and then move them to GPU in a main thread. It blocks the main thread, but it's pretty fast and not really noticeable.
* Worked on diagonal collision. I previously worked on it, but it was very buggy, as the player could get stuck between tiles (I noticed that some SNES and GBA games have this problem, e.g. Earthbound, Mother 3). But I fixed it! I hope that I'll never have to deal with tile collision in the near future. It's so hard!

{{< figure src="tile-collision.gif" >}}

There are probably a lot of things I missed, but I hope that it's enough to show you how much stuff I've done.

## Conclusion and plans

This semester is very intense. Lots of homework, project assignments and so on. This was the reason I stopped working on a game for a 1.5 months and probably won't be working on it for another two and a half.

In the meantime, I will be doing small things about the game which don't require coding: improve plot, think about game mechanics and puzzles, limit my scope, etc. I also plan to read stuff about game development and think how I can further improve my code and engine structure. It's not the main priority now, however. I'm mostly happy with most of my code and don't think that a huge changes will come.

What I want to have in the future is a stable foundation. You know, just some level with a lot of things going on: AI, NPCs, complex tile map, basic combat, particles and so on. A vertical slice of the game, working just fine. The confidence in the code base: that it works well and doesn't require me write a lot of boilerplate code and that I'm not limited by it. Good resource system, neat organization in files, smooth content creation and so on.

These are some things which take a lot of time, but once they're achieved, they can provide a lot of confidence and comfort in the future and save me from having to change a lot of things at once.

Don't worry about the project: I've taken a few breaks from it before and coming back was as exciting as ever. As the time goes on, I don't lose any motivation or confidence in it, in fact I love it more and more. And some of you may be disappointed in my slow progress, and I'm sorry for it, but not rushing is what makes it such a nice experience for me. And hey, even if you don't get the playable game in the end, you can still learn something from my dev logs and tutorials. If I didn't spend lots of time reiterating, researching, refactoring, I would have never figured out a lot of things which helped a lot of people.

One more thing: art, dialogue, plot, atmosphere and whole concept just got a lot better as the time went by. If I finished the game with the art, plot and gameplay it had two years ago, it would not be very good. But as my skills improve, I apply them to the game and make it considerably better than before.

Thanks for reading!

