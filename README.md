# Inlay

Render Ruby graphics where you inspect them. Inlay shows Tessel images, RBGL surfaces, and chart output in terminals, IRB, and Pry.

## Install

```sh
gem install inlay
```

Add `inlay` to your Gemfile. Inlay uses [Tessel](https://github.com/rbgfx/tessel) for images and [Termvas](https://github.com/rbgfx/termvas) for terminal output.

## Use in IRB

Add this to `~/.irbrc`:

```ruby
require "inlay/irb"
```

Now returning an image from a prompt displays it inline and leaves a short summary as the result:

```ruby
image = Tessel.read("brick.png").scale_nearest(64, 64)
image
```

Pry uses the same integration style:

```ruby
require "inlay/pry"
```

Inlay uses the terminal protocol selected by Termvas: Kitty, iTerm2, Sixel, or true-color half blocks. Piped output, `TERM=dumb`, `INLAY=off`, and `NO_COLOR` with half blocks show only the summary.

## Use in a script

```ruby
require "inlay"

image = Tessel.read("brick.png")
Inlay.show(image, width: 40)
Inlay.config.max_rows = 30
```

To install the short `inlay(value)` helper, require `inlay/kernel`. Explicit calls accept image paths; ordinary returned strings are never treated as paths.

Objects can implement `to_inlay` and return a `Tessel::Image`, `{ png: bytes }`, `{ svg: markup, png: -> { bytes } }`, or `{ frames: images, fps: number }`. Custom object types can also be registered:

```ruby
Inlay.register(MySurface) { |surface| surface.to_tessel_image }
```

## Configuration

`Inlay.config.enabled` toggles terminal rendering. `max_rows` caps terminal height and `max_pixels` limits decoded and displayed input size. Small images (up to 32×32) are enlarged with nearest-neighbor scaling; larger images are reduced with alpha-aware area averaging. Set `INLAY=off` to disable terminal output for a process.

## Development

```sh
bundle install
bundle exec rake verify
```

## License

MIT
