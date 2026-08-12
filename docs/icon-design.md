# Icon design

The mark is a reticle: a thin ring, four ticks crossing it, and a void at the
centre. The void is the whole idea — it is where the pointer sits, and it is
what separates a sight from a plus sign.

## How it got here

Three versions were built and two were thrown away, which is worth recording so
the same ground is not covered twice.

**The original** was a thick yellow plus with no centre gap. It read as "add" —
the wrong verb for an app about finding things — and yellow had no relationship
to anything the product draws.

**The second** was the sight rendered as a physical instrument: machined rim,
glass, specular highlight, its own shadow. It followed the reference style
Rasmus pointed at, and it was rejected as too heavy and too clumsy. The lesson
is that material simulation adds weight faster than it adds meaning, and at
32pt none of that detail survives anyway.

**What shipped** is drawn with strokes rather than modelled as an object. One
accent, one ground, no shadows, no gloss. Deep violet, white mark.

## Rules the drawing follows

Every size is drawn natively rather than downsampled. Below 64pt the stroke
thickens, the centre void tightens, and the ticks stop overshooting the ring —
because a naive resize loses all three long before 16pt. Verified legible at
16, 32, 64 and 128.

The ring sits at 30% of the tile, inside Apple's macOS icon grid (824 of 1024,
corner radius 185.4). Nothing bleeds past the tile.

`scripts/make_icon.swift` regenerates the whole set. Colour, stroke weight,
ring radius and the centre gap are all constants at the top of `draw`.
