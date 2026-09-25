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

## Use in IRuby / Jupyter

Install [IRuby](https://github.com/SciRuby/iruby) 0.8 or newer, then require Inlay after the optional graphics gems you use:

```ruby
require "inkplot" # optional: charts
require "inlay/iruby"

Tessel.read("brick.png")
Inkplot.line(prices, x: :date, y: :close) # when Inkplot is installed
```

IRuby provides PNG for images and both SVG and PNG for charts, with SVG listed first. Animations use an installed Flipbook to produce a GIF data URI; if Flipbook is unavailable, Inlay displays the first frame as PNG. These integrations are opt-in and do not load IRuby, Inkplot, or Flipbook when you only `require "inlay"`.

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

Run `bundle exec rbs -I sig validate` to check the published signatures. The manual terminal and notebook checklist is in [docs/manual-checks.md](docs/manual-checks.md).

## License

MIT
