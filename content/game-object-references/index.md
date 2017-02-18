---
title: "Making and storing references to game objects (entities) in C++ and Lua"
date: 2017-01-22T14:00:00+03:00
draft: false
tags: [C++, Lua, Gamedev, Tutorial]
---

{{< toc >}}

## Introduction

{{< figure src="ids.png" >}}

The problem of handling references to game objects (I'll call them *entities*) comes up very often. Sometimes it's child-parent relationship between the entities, sometimes it's useful to store a reference to an object in event data, some task scheduling class and so on.

Sometimes a simple pointer, reference or `std::reference_wrapper` is enough. But the problem with raw pointers and references is that once you use them, you have to make sure that the entity which is being referenced stays alive and is not moved in memory without notifying objects which hold references. And with good design you'll probably be able to achieve that.

But stale pointers/references give some of the worst bugs, which are difficult to track, crash your game and may not be easily identifiable. Some entities may start to occupy different addresses in memory (for example, after you reload a level and decide to create all entities from scratch). While it's possible to manually update all pointers to previously referenced entities, it's certainly will be better to do so automatically and without a chance of forgetting some pointers which will be stale.

Let's see all these problems can be solved. The latest solution (about storing references to Lua) was discovered by me not long ago and it is the point of me writing the article, but I want to show some other ways of solving the problem. Let's start!

## shared_ptr and weak_ptr

Some of the problems with raw references can be solved with `std::shared_ptr` and `std::weak_ptr`. First, you create your entities as with `std::make_shared`. After that you'll create all references to it with `std::weak_ptr`s which won't affect your entity's lifetime. After that you can use `std::weak_ptr<T>::expired` function to check if the reference is still valid.

The solution is not perfect. First of all, it requires you to create all your entities as `shared_ptr`s which may have some significant overhead compared to `unique_ptr`s. And after all, it's better for the lifetime of entities not to be shared and that semantic is better expressed with `unique_ptr`. Shared pointers also don't solve the problem of moving entities in memory: you can't swap what's inside the `shared_ptr` and have all `weak_ptr`s automatically update their pointers.

## Using unique ids

One solution to the problem is just creating unique ids for entities and storing those ids instead of raw pointers or references. There a lots of ways to generate and represent entity ids. Ids can just be integers with `EntityManager` having a counter which will be incremented as new entities are created: the first entity will get id=0, the second one id=1 and so on. Another way to generate ids is to use some hashing algorithm or [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier)s. No matter what, your ids should stay unique, unless you add some additional info (like entity creation time or some tags) to your id.

Here's how your `EntityManager` class may look:

```cpp
class EntityManager {
public:
    Entity* getEntity(EntityId id) const;
    bool entityExists(EntityId id) const;
    // ...
private:
    std::unordered_map<EntityId, std::unique_ptr<Entity>> entities;
    // ...
};
```

Using ids also helps with recreation problem: you can easily reload/recreate the entity and just assign the same id to it as before. It will have a different adress in memory, but the next time someone calls `getEntity` the updated entity is returned. You can also easily send these ids over the network or save them in your save files.

Your code when using entity id becomes something like this:

```cpp
auto entityPtr = g_EntityManager.getEntity(entityId);
entityPtr->doSomething();
```

Of course this creates some overhead because you now have a layer of indirection: you have to search `unordered_map` inside the `EntityManager` to get the raw reference to the entity, but if you don't do it too often (and you most likely won't), you'll be fine!

There's another improvement which can be done: you can wrap your id inside the struct and then overload `operator->` for handle to act like a raw pointer:

```cpp
struct EntityHandle {
    EntityId id;
    EntityManager* entityManager;

    EntityHandle(EntityId id, EntityManager* entityManager) :
        id(id), entityManager(entityManager)
    {}

    Entity* operator->() const {
        return get();
    }

    Entity* get() const {
        assert(entityManager->entityExists(id));
        return entityManager->getEntity(id);
    }
};
```

Now you can do things like this:

```cpp
EntityHandle handle(someEntityId, &g_EntityManager);
handle->doSomething();

// or...

auto entityPtr = handle.get();
entityPtr->doSomething();
```

Notice that we also get some error checking with assert which checks validity of the reference.
Great! Now let's see how we can reference entities in Lua scripts.

## Storing references to entities in Lua

{{< hint info >}}
Full implementation can be found here: [C++ part](https://gist.github.com/eliasdaler/f5c2ee50fc7e42bf3ee18ad7d46d18f8), [Lua part](https://gist.github.com/eliasdaler/f3516d3deabc32b465a7c244ff082cf0).
{{< /hint >}}

First of all, it's obvious that you can use the same approach in Lua. Your handle can just be a number or a table with `__index` meta-method so that you can use your handle as if it was the raw reference. But there's a neater method I recently came up with. Let's see how it works.

First of all, our handles will be tables with raw C++ references stored in them as userdata. They'll also have a bool named `isValid` which will help us test if the handle is still valid. We'll also have a global table of references in Lua, so that you can easily get handle from any place without calling C++. What's neat is that you'll get **references** to your handles, not a copy. It's great, because you can easily compare two handles or even use them as table keys. You also don't waste your memory, but that's not a big concern as our handles are very light.

If you want to remove and recreate some entity, you'll just have to notify the main Lua handle which will be stored inside some global Lua table. And because all your handles in Lua will be references to original handle you won't have to care about them: once you update the main handle, it's updated everywhere.

Another good thing is that once the entity is removed, we can just set `isValid` to `false` and raw reference to `nil` just to be extra safe.

Let's get to implementation! We'll use <i class="fa fa-github" aria-hidden="true"></i>[sol2](https://github.com/ThePhD/sol2) as our Lua/C++ binding library. Let's write a simple `Entity` and `EntityManager` classes for testing:

```cpp
using EntityId = int;

class Entity {
public:
    explicit Entity(EntityId id) :
        name("John"), id(id)
    {}

    const std::string& getName() const { return name; }
    void setName(const std::string& n) { name = n; }
    EntityId getId() const { return id; }
private:
    std::string name;
    EntityId id;
};

sol::state lua; // globals are bad, but we'll use it for simpler implementation

class EntityManager {
public:
    EntityManager() : idCounter(0) {}

    Entity& createEntity()
    {
        auto id = idCounter;
        ++idCounter;

        auto inserted = entities.emplace(id, std::make_unique<Entity>(id));
        auto it = inserted.first; // iterator to created id/Entity pair
        auto& e = *it->second; // created entity
        lua["createHandle"](e);
        return e;
    }

    void removeEntity(EntityId id)
    {
        lua["onEntityRemoved"](id);
        entities.erase(id);
    }
private:
    std::unordered_map<EntityId, std::unique_ptr<Entity>> entities;
    EntityId idCounter;
};
```

Here's how we will create our handle in Lua:

```lua
function createHandle(cppRef)
    local handle = {
        cppRef = cppRef,
        isValid = true
    }
    setmetatable(handle, mt)
    Handles[cppRef:getId()] = handle
    return handle
end
```

The `Handles` global table stores all handles so that we can easily get them later. As you can see, we still use integer ids for it as a tables key so that when we remove an entity, we can easily find its handle and modify it appropriately.

The metatable has an important function: it will let us use the handle as if it was the original reference. Here's how it's written:

```lua
local mt = { }
mt.__index = function(handle, key)
    if not handle.isValid then
        print(debug.traceback())
        error("Error: handle is not valid!", 2)
    end

    return function(handle, ...) return Entity[key](handle.cppRef, ...) end
end
```

Just a quick reminder: metatable's `__index` function gets called when the key in the table is not found and the table (our handle) and missing key are passed.

Here's an example of how it all works. When we do this:

```lua
handle:setName("John")
```

Lua checks if handle table has "setName" key, but it doesn't, so it calls metatable's `__index` function with handle and "John" as parameters. The wrapper around `Entity`'s member function is returned and it gets called. The function which gets returned is a closure which calls the `Entity`'s class member function on original raw reference. Why can't we just return `Entity[key]`? The problem with that is that our handle will get passed into it while the function expects raw reference to be passed (`cppRef:setName("John")` is the same as calling `Entity.setName(cppRef, "John")`).

The error checking that we have here is extremely important and useful! It allows us to easily debug problems with our code: we even print the call stack to find the place where our code crashed!

{{< hint info >}}
Notice that we pass "2" as the second argument in `error` function. It tells it that the problem is not the function which called it, the bad one was below it in a call stack.
{{< /hint >}}

Another great thing about this implementation is that it lets us handle error on Lua side, not C++ side. Once the C++ function is called from Lua, it's hard to properly throw and catch an error from C++. You'll have to compile Lua as C++ to do it without a crash. Throwing the error before calling C++ allows us to safely catch it on Lua side and handle it appropriately. We'll see how it can be done a bit later.

Let's test out reference first:

```lua
function test(cppRef)
    local handle = createHandle(cppRef)
    testHandle(handle)
end

function testHandle(handle)
    print("Hello, my name is " .. handle:getName())
    handle:setName("Mark")
    print("My name is " .. handle:getName() .. " now!")
end
```

Output:

<pre style="background-color:black;color:white">Hello, my name is John
My name is Mark now!</pre>

It works! What should we do when entity gets removed? Let's create a function for that:

```lua
function onEntityRemoved(id)
    local handle = Handles[id];
    handle.cppRef = nil
    handle.isValid = false
    Handles[id] = nil
end
```

We need to call it before our entity gets removed and you can place it into `Entity`'s destructor or into `EntityManager`'s `removeEntity` function. Note, that this doesn't remove the handle itself: someone may still be referencing it, but setting corresponding value in `Handles` table to `nil` is still useful because if someone tries to grab a handle later, `nil` will be returned. What's more important is that `isValid` is set to false so that the next time someone tries to use the handle, the error will be raised.

Now let's see what happens when we try to use invalid reference. We can even do our error handling in Lua now!

```lua
function testBadReference()
    local handle = Handles[0] -- this handle exists and is okay
    handle.isValid = false -- but suppose that entity was removed!
    local _, err = pcall(testHandle, handle)
    if err then
        print(err)
    end
end
```

When we call this function from C++ we don't get a crash which would have been caused by using stale reference. Instead, we get a helpful error message and call stack:
```sh
stack traceback:
    script.lua:23: in function 'getName'
    script.lua:57: in function <script.lua:56>
    [C]: in function 'pcall'
    script.lua:65: in function <script.lua:62>
script.lua:57: Error: handle is not valid!
```

What about the performance? My tests show that it's around **600 nanoseconds** per C++ member function call. It's not that bad, but still may be not good enough for some people. In that case it's easy to get a raw reference and then use it without any additional overhead of error checking:

```lua
local rawRef = handle.cppRef
print("Raw reference used. Name: " .. rawRef:getName())
```

We can also speed up `__index` function. I've found that its biggest overhead is creating a closure every time... so let's memoize our wrapper functions! First of all, we'll create a table which will store our wrapper functions:

```lua
local memoizedFuncs = {}
```

And then we change our `__index` method to this:

```lua
mt.__index = function(handle, key)
    if not handle.isValid then
        print(debug.traceback())
        error("Error: handle is not valid!", 2)
    end

    local f = memoizedFuncs[key]
    if not f then
        f = function(handle, ...) return Entity[key](handle.cppRef, ...) end
        memoizedFuncs[key] = f
    end
    return f
end
```

The closure for each function will be created once and then will get reused. This speeds up things considerably! The overhead is roughly **200 nanoseconds** per call.

What else? Calling the function through `__index` produces additional overhead too. Suppose that we use `getName` function very often and want it to be part of our handle table so that it's called directly. Ok, let's do this!

```lua
function createHandle(cppRef)
    local handle = {
        cppRef = cppRef,
        isValid = true
    }
    handle.getName = function(handle, ...)
        return Entity.getName(handle.cppRef, ...)
    end

    setmetatable(handle, mt)
    Handles[cppRef:getId()] = handle
    return handle
end
```

Wait a second... what happens when we call getName on bad handle? There's no error checking! Let's fix that:

```lua
function getWrappedSafeFunction(f)
    return function(handle, ...)
            if not handle.isValid then
                print(debug.traceback())
                error("Error: handle is not valid!", 2)
            end
            return f(handle.cppRef, ...)
        end
end
```

and then in createHandle we'll write:

```lua
handle.getName = getWrappedSafeFunction(Entity.getName)
```

Now the overhead is just **70 nanoseconds**. The only added overhead is additional function call, validity check and retrieval of raw reference from handle table, but I think it's pretty small for gained benefits.
