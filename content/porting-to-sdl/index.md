---
title: "Porting my engine from SFML to SDL"
date: 2020-05-17T00:00:00+03:00
tags: [C++, C, SFML, SDL, game dev, Tomb Painter, dev log]
---

Recently I've ported my game/engine from SFML to SDL. This was not an easy task
and took me two weeks of hard work (3-4 hours on weekdays, 6-8 hours on
weekends). This article will explain why I did it and which challenges I've
faced in the process.

{{< figure src="title-image.jpg" >}}

{{< toc >}}
## Intro

{{< figure src="first-game.png" caption="My first SFML project" >}}

SFML has played a huge part in my life. I've started using it 8 years ago (in
2012) and it was then when things finally clicked for me in game programming.

My second SFML project (Re:creation):

{{< video width="480px" label="recreation" mp4="re-creation.mp4" >}}

SFML is a perfect library for a beginner. In one framework you have pretty much everything
to make a simple 2D game: window creation, 2D graphics helpers, TTF rendering,
audio, input, networking and so on. In a few lines of code you can get your
simple prototype running, compared to SDL or GLFW, where you need to do much
more (it was especially true before `SDL_Renderer` became better and didn't have
accelerated graphics support). If you're not planning to make a huge game, but
still don't want to use an engine, SFML is a solid choice. [These
videos](https://www.youtube.com/playlist?list=PLB_ibvUSN7mzUffhiay5g5GUHyJRO4DYr) show
how powerful SFML can be and how fast you can iterate with it.

## Why port my game to SDL?

My main reason for porting to SDL was my engine's preservation and future. SDL
is a very stable framework and is [widely
used](https://en.wikipedia.org/wiki/List_of_games_using_SDL) and supported
(especially by Valve - it's basically integrated into Steam at this point and
been used as a main tool for porting many games to Linux).

As I developed my games and engine for yet another year, I've realized that my
engine will be with me for a really long time. At the same time, OSes don't
stand still - they sometimes change their APIs (macOS especially loves to do
this), they introduce new bugs and incompatibilities. SFML was pretty
up-to-date in the 2012-2017, but then I've felt that it just couldn't keep up
with rapidly changing environment. It still supported very old joysticks, for
example, but had some bugs popping up on macOS and its mobile phone support was
not supported well.

SDL is a widely used framework and it's a very nice thing - the bugs are
reported faster and get resolved quicker. When you have a lot of games running
on a framework, you don't want to see it being broken - and so you tend to put
more effort into its support and preservation. This is not the same for SFML -
there are only a couple of commercial games made with it, and most of them are
not made by AAA or even AA studios.

Another issue with SFML is a crawling speed of its development. There are [a
lot](https://en.sfml-dev.org/forums/index.php?board=2.0) of
long-awaited features and bugs to be fixed. This is a direct result of what I've
talked in the paragraph above - SFML is mostly a hobbyist library, so there's
not a lot of developers working on it. Even one full-time developer would have
made a world of difference, but SFML doesn't have them.

One example of this is scancodes - I've provided [a PR for Linux
implementation](https://github.com/SFML/SFML/pull/1400)
two years ago. And even though the code was accepted, the implementation is not
merged into master, because other implementations are still not complete or buggy.

There's also a lot of conservatism from some people on SFML team - it's mostly
justifiable, given that there's not enough developer time to support all the
extra features and APIs, but at the same time it feels like you don't have
enough things that could easily be added and be very useful.

There's also an "SFML 3" discussion floating around, which is about dropping
C++03 support in SFML and finally starting to use C++11 (and later) features and
making SFML's API easier and safer to use, and dropping support for a lot of
things at the same time (e.g. the abstraction on threads can be removed, because
we have std::thread now). The discussion has been going around for years, but
there is still no clear sign of when such thing will be finally developed.

You get the idea. SFML could be much greater than it is now, but basically
nothing has happened with it in the past 5 years, except for implementing some
features which SDL had for a long time.

{{< hint info >}}
**Update (2022)**: [Vittorio Romeo](https://vittorioromeo.info/) has been doing a lot of SFML modernization lately. So it's not as grim as it seemed back then.
{{< /hint >}}

I can go on, but here's a summarization of all the things which made me choose
SDL over SFML:

* SDL has commercial support, which results in bugs being found and resolved
  quicker
* SDL has better portability
* SDL deals with a lot of OS quirks (down to update versions for Windows, for
  example)
* SFML will probably not get features which will make it superior for modern C++
  development soon, so at this point using a C library is as good as using C++03
  library for me.
* SDL has better gamepad support (thanks to its huge [controller
  DB](https://github.com/gabomdq/SDL_GameControllerDB)).
* SDL handles multi-display setups better
* SDL has various features not present in SFML (IO streams abstraction, message
  box abstraction, and so on)

## Porting to SDL - the process

The porting process was very daunting at first - even though I've tried to keep
my SFML-related code separate, parts of it still leaked into higher level
things. I've also used a lot of graphical features of SFML, which SDL doesn't
have in its `SDL_Renderer` module to this day or which have entirely different
API from SFML's.

One thing that helped me moving quicker is realization that I can replace SFML
code with SDL code without breaking SFML part. Imagine if I just chose to not
link to SFML and start to rewrite all the things module by module - it would
take a lot of time to even get the thing to compile, getting it to run properly
would be even harder.

I've decided to not use `SDL_Renderer` or `SDL_gpu` for rendering, because I've
realized that the porting would be much easier if I could write my own similar
classes for sprites, render textures and other stuff, so that its behaviour is
similar to SFML's graphical primitives. I've chosen to write the whole graphics
part in OpenGL.


{{< figure src="imgui.png" caption="Getting Dear ImGui to work with SDL/OpenGL was encouranging" >}}

Before that, the only thing I knew about OpenGL is how to draw a triangle with
it, so it was additional challenge for me, but one that I took with a great
interest, because I wanted to properly learn modern OpenGL for a long time.

However, this presented new problems - SFML uses legacy OpenGL (its immediate
mode with `glBegin` and `glEnd` everywhere), so I couldn't just follow SFML's
implementation to get my own version of its graphics API. I'm still glad that I
used so many parts of SFML's graphics module, though, because a lot of OpenGL
concepts like vertex buffers (`sf::VertexBuffer`), frame buffers
(`sf::RenderTexture`), shaders (`sf::Shader`), viewport matrix (`sf::View`) and
other things had abstractions in SFML, so I understood the concepts well.

A lot of tutorials helped me get used to OpenGL. Here are some of them:

* [learnopengl.com](https://learnopengl.com), Joey de Vries tutorials
* [Tom Dalling's modern OpenGL
  tutorials](https://www.tomdalling.com/blog/category/modern-opengl/)
* [Joe Groff's OpenGL
  articles](http://duriansoftware.com/joe/An-intro-to-modern-OpenGL.-Table-of-Contents.html)

For the math library, I've chosen [glm](https://glm.g-truc.net/), which proved to be amazing and helped
me out with a lot of math stuff (especially matrices and transforms). I've
eventually replaced my own vector class with `glm::vec2`/`glm::ivec2` and
now it's used consistently through the whole codebase (with SFML I had to
convert to `sf::Vector2<T>` back and forth, which was annoying).

The only huge problem I had with `glm` is that it didn't initialize its vectors
and matrices to zero by default. It wasn't noticeable at first, but then I've
spent a few hours debugging some sprites being missing from time to time...
turns out it was caused by uninitialized `glm::vec2`. I turned on
`GLM_FORCE_CTOR_INIT` and never looked back (I still try to initialize vectors
explicitly, but sometimes you just forget to do it!).

As the result, I now have a bunch of classes closely following SFML's API, but I
could finally change the API to my liking and not implement all the things that
I didn't like or didn't use.

There was another problem - SFML screwed with OpenGL context even if I wasn't
rendering anything with SFML's graphics API. For example, creating an instance of
`sf::RenderTexture` caused graphical errors and crashes. I didn't even need to
call `sf::RenderTexture::create` for it to happen! But other than that, creating
SFML objects along my own graphics objects didn't cause any problems, so
good-ol' `ifdef`'s came to the rescue:

```cpp
class GraphicsComponent : ... {
   ...
   sf::Sprite sprite;
   edge::Sprite sprite2; // my verision of sprite
};

// somewhere in the rendering system
#ifdef USE_SFML
    window.draw(gc.sprite);
#else
    window_sdl.draw(gc.sprite2);
#endif
```

Why `sprite` and `sprite2`, you might ask? Because If I had written something
like this:

```cpp
class GraphicsComponent : ... {
   ...
#ifdef USE_SFML
   sf::Sprite sprite;
#else
   Sprite sprite;
#endif
};
```

... then I'd get a lot of compiler errors in all the systems which used `sprite`
in any way, but I chose a more iterative approach - I didn't allow some
systems/functions to run in SDL mode and got them working properly one by one.

Another thing that really saved me was making a small project with my engine
before the porting began. This way, it was easier to get things working
iteratively without breaking my main big project. Once I could get all the
graphical things working one by one in this small environments, I could finally
move on to making my game work correctly.

Porting input was easy - I'm using an abstraction on keyboards and gamepads:
when you press "Z" on the keyboard or "A" on the gamepad, the "PrimaryAction"
event gets sent and the game logic handles it, instead of checking for
keyboard/gamepad state manually. Therefore, all I had to do was to replace the
code which handled framework's events (`sf::Event` to `SDL_event`), and it was
all done - no changes to game input logic.

At this point, my game was up and running. Even if it didn't have proper shaders
and had some graphical issues, it was fully playable, which was really
satisfying, because it proved to me that my game logic was independent from the
framework it was running on (I didn't need to change a thing in game logic, in
part because I didn't export any SFML classes to Lua, so I only had to change
implementation of some C++/Lua bindings like `setSpriteColor` or `setTexture`)

{{< figure src="tomb-painter-1.png" caption="Tomb Painter running Tomb Painter running for the first time on SDL. Some animations were broken, no palette or lighting shaders, but it’s playable!" >}}

The audio proved to be a lot more trickier - I've initially just commented out
all audio code until I was done with everything else, but once I needed to port
my audio code I've decided to implement some simple Sound and Music class
similar to SFML's using OpenAL-soft - and [these
tutorials](https://indiegamedev.net/2020/02/15/the-complete-guide-to-openal-with-c-part-1-playing-a-sound/)
really helped me out with it.

Porting level editor was not easy. There were absolutely no problems with Dear
ImGui running on SDL instead of SFML - not much has changed in UI code, except
for me having to make some wrappers around my `Sprite` classes to get
`ImGui::Image` and `ImGui::ImageButton` to work. However, I used a lot of SFML's
more complex features for implementing level editor camera and drawing debug
info, so I had to spend a lot of time porting all of that to my own graphics system.

{{< figure src="editor.png" caption="Level editor running" >}}

## Results

Here's the result of my porting efforts:

{{< figure src="commit.png" caption="The final commit in porting branch. Game + engine is ~40k loc in total, so I change quite a big percentage of it.">}}

10 days have passed since the porting was finished, and so far I didn't notice
any bugs caused by it. In fact, it was just yesterday that I remembered that I
have ported my game at all to SDL. And it's a good thing, which makes that the
engine's base is stronger than ever, but my main development process has not
slowed down a bit.

SDL with modern OpenGL are pleasant to use, and now as I'm closer to low level, I can
implement things that wouldn't be as easy to do with just SFML. Let's see where
it leads me!

Thanks for reading!

