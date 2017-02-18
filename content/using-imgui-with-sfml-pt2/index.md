---
title: "Using Dear ImGui with modern C++ and STL for creating awesome game dev tools"
date: 2016-07-21T20:34:00+0300
lastmod: 2021-01-12T23:40:00+30:00
draft: false
---

Related article: [Using Dear ImGui with SFML for creating awesome game dev tools]({{< ref "/using-imgui-with-sfml-pt1" >}})

---

This is my second article about Dear ImGui! This article is a collection of useful things, hacks and other stuff I've found while using ImGui. Mostly it's focused on using modern C++ and some parts of STL with ImGui.

{{< figure src="imgui-widgets.png" title="Different Dear ImGui widgets" >}}

{{< toc >}}

## Labels

Labels are used in ImGui as unique IDs for widgets. You shouldn't use same labels for two different widgets as it will introduce collisions between widgets and that will lead to some unwanted behavior.

Suppose you have two buttons with label "Meow" and you have a code like this:

```cpp
if (ImGui::Button("Meow")) {
    std::cout << "Meow\n";
}

if (ImGui::Button("Meow")) {
    std::cout << "Purr\n";
}
```

The first button works as expected, but the second doesn't work at all! These are the things that can happen when collisions occur between IDs. This won't happen most of the time, after all there's mostly no need to place two buttons which say the same thing in one window. But what if you *really* need these two "Meow" buttons? The solution is simple: you just have to add "##" and some stuff after that to resolve the collision:

```cpp
if (ImGui::Button("Meow")) {
    std::cout << "Meow\n";
}

if (ImGui::Button("Meow##Second")) {
    std::cout << "Purr\n";
}
```

All the text after "##" is not displayed and only used to give unique IDs to widgets with same labels.
IDs should be unique in the same scope, so it's okay to have two widgets with the same label in two different windows or have one of them in some tree or list (trees, lists and some other widgets have their own scopes, so collisions won't happen between items in them and other items).

Let's look at another situation. Suppose you have an array of `int`s:

```cpp
std::array<int, 10> arr = { 0 };
```

And now you want to create a bunch of `InputInt` widgets for each array element. `ImGui::PushID`/`PopID` come to the rescue! You can push `int`s, `const char*` or `void*` as IDs which will be appended to the label of the next created widget (but won't be shown). For example, you can do this:

```cpp
for (int i = 0; i < arr.size(); ++i) {
    ImGui::PushID(i);
    ImGui::InputInt("##", &arr[i]);
    ImGui::PopID();
}
```

There are some situations where you don't have an `int` which you can use as part of ID, for example if you want to use for-ranged loop with the `std::array`. In that case, you can use pointers to elements of the array which will be unique:

```cpp
for (auto& elem : arr) {
    ImGui::PushID(&elem);
    ImGui::InputInt("##", &elem);
    ImGui::PopID();
}
```

## Getting back to the context of the window, tree, etc.

Suppose that you need to add some stuff to the window you've created before but you already called `ImGui::End`. No problem, just call `ImGui::Begin` with the name of the window in which you want to append stuff. Here's an example:

```cpp
ImGui::Begin("First window"); // begin first window
// some stuff
ImGui::End();

ImGui::Begin("Another window"); // begin second window
// some another stuff
ImGui::End();

// oops, forgot to add some stuff!
// let's go back to the context of the first window
ImGui::Begin("First window");
// forgotten stuff
ImGui::End();
```

## InputFloatN + struct

Sometimes it's useful to use `InputFloat2` or `InputFloat4` with your point or rectangle structs which can be defined like this:

```cpp
struct Point {
    float x;
    float y;
};

struct Rect {
    float x;
    float y;
    float w;
    float h;
};
```

Using them with `InputFloat2` or `InputFloat4` is easy:

```cpp
Point p{ 0.f, 0.f };
Rect r{ 0.f, 0.f, 0.f, 0.f };
```

```cpp
ImGui::InputFloat2("Point", &p.x);
ImGui::InputFloat4("Rect", &r.x);
```

This works because both `Point` and `Rect` structs are [POD](http://en.cppreference.com/w/cpp/concept/PODType) and don't have "holes" in them, so the data they store is contiguous and can be interpreted as array of floats.

This method is not very safe, of course, so use it at your own risk. Someone can modify the struct and this may break your code which assumed that the floats you want to modify are stored contiguously. Unfortunately, there's no way to pass array of pointers to `InputFloat2` or `InputFloat4`, but you can easily create your own solution. Let's make a function which creates a widget similar to `InputFloat4` and uses members of `Rect` struct explicitly:

```cpp
namespace imgui_util {

bool InputRect(const char* label, Rect* rectPtr,
    int decimal_precision = -1, ImGuiInputTextFlags extra_flags = 0)
{
    ImGui::PushID(label);
    ImGui::BeginGroup();

    bool valueChanged = false;

    std::array<float*, 4> arr = { &rectPtr->x, &rectPtr->y,
                                  &rectPtr->w, &rectPtr->h };

    for (auto& elem : arr) {
        ImGui::PushID(elem);
        ImGui::PushItemWidth(64.f);
        valueChanged |= ImGui::InputFloat("##arr", elem, 0, 0,
            decimal_precision, extra_flags);
        ImGui::PopID();
        ImGui::SameLine();
    }

    ImGui::SameLine();
    ImGui::TextUnformatted(label);
    ImGui::EndGroup();

    ImGui::PopID(); // pop label id;

    return valueChanged;
}
```

And now you can do this:

```cpp
imgui_util::InputRect("Rect", &r);
```

<pre class="vs-code"><span class="cppNamespace">ImGui</span><span class="operator">::</span><span class="cppFunction">InputRect</span><span class="operator">(</span><span class="string">&quot;Rect&quot;</span><span class="operator">,</span> <span class="operator">&amp;</span><span class="cppLocalVariable">r</span><span class="operator">);</span>
</pre>

## Using ImGui with STL

There are lots of things to be said about using ImGui with STL. ImGui doesn't use STL at all and users have to pass raw arrays and `const char*`s instead of `std::vector`s and `std::string`s, so you can't just use STL and some modern C++ right away, but it can be done with some work.

### Arrays

Some widgets require you to use raw arrays but those are not the best because you can't use them with algorithms, for ranged loops, etc. And the other problem is that you have to manage the memory of variable size arrays yourself using `new` and `delete`. Using `std::array` with `Imgui::InputInt4` which expects you to pass raw array is easy, just do it like this:
<pre class="vs-code"><span class="cppNamespace">std</span><span class="operator">::</span><span class="cppType - keyword - (TRANSIENT)">array</span><span class="operator">&lt;</span><span class="keyword">int</span><span class="operator">,</span> <span class="number">4</span><span class="operator">&gt;</span> <span class="cppLocalVariable">arr2</span> <span class="operator">=</span> <span class="operator">{</span> <span class="number">0</span> <span class="operator">};</span>
</pre>
<pre class="vs-code"><span class="cppNamespace">ImGui</span><span class="operator">::</span><span class="cppFunction">InputInt4</span><span class="operator">(</span><span class="string">&quot;IntRect&quot;</span><span class="operator">,</span> <span class="cppLocalVariable">arr2</span><span class="operator">.</span><span class="cppMemberFunction">data</span><span class="operator">());</span>
</pre>

```cpp
std::array<int, 4> arr2 = { 0 };
```

```cpp
ImGui::InputInt4("IntRect", arr2.data());
```

`std::array::data` returns a pointer to raw int array which can be passed to `ImGui::InputInt4`.

The same can be done with `std::vector`s which are guaranteed to be contiguous, so you can just use `std::vector::data` the same way:

<pre class="vs-code"><span class="cppNamespace">std</span><span class="operator">::</span><span class="cppType">vector</span><span class="operator">&lt;</span><span class="keyword">int</span><span class="operator">&gt;</span> <span class="cppLocalVariable">arr3</span><span class="operator">(</span><span class="number">4</span><span class="operator">,</span> <span class="number">0</span><span class="operator">);</span>
</pre>
<pre class="vs-code"><span class="cppNamespace">ImGui</span><span class="operator">::</span><span class="cppFunction">InputInt4</span><span class="operator">(</span><span class="string">&quot;IntRect&quot;</span><span class="operator">,</span> <span class="cppLocalVariable">arr3</span><span class="operator">.</span><span class="cppMemberFunction">data</span><span class="operator">());</span>
</pre>

```cpp
std::vector<int> arr3(4, 0);
```

```cpp
ImGui::InputInt4("IntRect", arr3.data());
```

### ComboBox, ListBox
`ComboBox` and `ListBox` can be used with arrays of `const char`s, but what if you have `std::vector<std::string>` instead? No problem, just use `BeginCombo`/`EndCombo`/`Selectable`:

```cpp
std::vector items{"a", "b", "c"}; // defined somewhere
int selectedIndex = 0; // you need to store this state somewhere

// later in your code...
if (ImGui::BeginCombo("combo")) {
    for (int i = 0; i < items.size(); ++i) {
        const bool isSelected = (selectedIndex == i);
        if (ImGui::Selectable(items[i], isSelected)) {
            selectedIndex = i;
        }

        // Set the initial focus when opening the combo
        // (scrolling + keyboard navigation focus)
        if (isSelected) {
            ImGui::SetItemDefaultFocus();
        }
    }
    ImGui::EndCombo();
}
```

### InputText and std::string

Dear ImGui lets you pass char array in `InputText` and then it modifies it when user enters some text in the input field. The problem is that it's hard to know the size of input in advance, so you have to allocate large enough buffer and then pass it in `InputText`.

However, there's a special overload for `InputText` and `InputTextMultiline` which allows you to use `std::string` with it. You need to include a special header to access it:

```cpp
#include <misc/cpp/imgui_stdlib.h>

struct Person {
    std::string name;
};

// later in code...
if (ImGui::InputText("name", &person.name) { ... }
```
