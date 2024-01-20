## 2DPush

A simple drop-in physics character that is based around tilemap movement. Rewritten and extracted logic
from a personal project to tidy up and reuse code.

### How

Add a `PushBody2D` to your scene, and place it as a child node of a tilemap, or assign `initial_tilemap` in the editor.
If you're creating it in code, simply assign `initial_tilemap` before adding it as a child.

`PushBody2D` comes with speech bubbles and annotated progress bars for free. Not using these features means nothing is done
and will not incur any performance cost. Not that using them would impact anything either.

### Cheatsheet

- `PushBodyMarker` is a sprite2d that can be added as a child to a pushbody2d to show visuals for a pushbody's actions.
it will pop up and fade away to show new locations, failed movements, and pushes.
- `PushBody2D.speak("hi")` pushbodies come with an extremely simple, optional, stylable overhead chat option.
You can preview your styling in editor.
- `PushBody2D.show_bar("HP", current_hp/max_hp)` takes in 0-1 as progress for the bar, it will show up and stay for a set amount
of time before fading away. Perfect for notifying a cast time, or showing hp for a bit.