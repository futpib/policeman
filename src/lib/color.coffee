
{ zip } = require 'utils'


exports.Color = class Color
  constructor: (c) ->
    [@r, @g, @b, @a] = @toRgbaArray c

  RGB = 'rgb'.split('')
  RGBA = 'rgba'.split('')

  chunksOf2 = (a) ->
    res = []
    i = 0
    while i < a.length
      res.push a.slice(i, 2)
      i += 2
    return res

  toRgbaArray: (c=@) ->
    # Converts various representations to [r, g, b, a] with 0 <= v <= 1 values
    if c instanceof Array
      if c.length == 4
        return c.slice()
      if c.length == 3
        return c.slice().concat 1
    if (typeof c == 'object') and RGBA.every((k) -> k of c) # {r:, g:, b:, a:}
      return RGBA.map (k) ->
        parseFloat(c[k])
    if typeof c == 'string'
      if c.startsWith 'rgba('
        numbers = c.slice(5, -1).split(',')
        rgb = numbers.slice(0, 3).map((x) -> parseInt(x)/255)
        a = parseFloat(numbers[3])
        return rgb.concat a
      if c.startsWith 'rgb('
        return c.slice(5, -1).split(',').slice(0, 3).map((x) -> parseInt(x)/255).concat 1
      if c.startsWith '#'
        if c.length = 4 #rgb
          return c.slice(1).split('').map((c) -> parseInt(c+c, 16)/255).concat 1
        if c.length = 5 #rgba
          return c.slice(1).split('').map((c) -> parseInt(c+c, 16)/255)
        if c.length = 7 #rrggbb
          return chunksOf2(c.slice(1)).map((c) -> parseInt(c, 16)/255).concat 1
        if c.length = 9 #rrggbbaa
          return chunksOf2(c.slice(1)).map((c) -> parseInt(c, 16)/255)

  toRgbaObject: (c=@) ->
    result = {}
    for [k, v] in zip RGBA, @toRgbaArray c
      result[k] = v
    return result

  toCssString: (c=@) ->
    rgba = @toRgbaArray c
    rgb255 = rgba.slice(0, 3).map((v) -> Math.round(v*255))
    rgba = rgb255.concat rgba[3].toFixed(2)
    return "rgba(#{ rgba.join(', ') })"

  # inspired by SASS mix
  mix: (other, weight=.5) ->
    other = @toRgbaObject other

    w = weight * 2 - 1
    a = @a - other.a

    w1 = ((if w * a == -1 then w else (w + a) / (1 + w * a)) + 1) / 2
    w2 = 1 - w1

    resultArr = RGB.map((k) => @[k] * w1 + other[k] * w2)
    resultArr.push(@a * weight + other.a * (1 - weight))

    return new Color resultArr
