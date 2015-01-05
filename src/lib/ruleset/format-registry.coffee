
{ path, file } = require 'file'


exports.registry =
  _records: []

  PRIORITY_HIGH: 100
  PRIORITY_MEDIUM: 0
  PRIORITY_LOW: -100

  register: (format, priority=@PRIORITY_MEDIUM) ->
    record = { format, priority }
    ix = @_records.findIndex (r) -> r.priority < priority
    @_records.splice ix, 0, record

  parse: (args...) ->
    [source, url] = args
    for record in @_records
      { format } = record
      if format::guess args...
        try
          return new format args...
        catch e
          log.debug 'Format::guess returned true, but constructor throwed on error',
                    'format:', format, 'error:', e
    throw new Error 'Unrecognized format'

  parseByLocalUrl: (url) ->
    return @parse (file.read url), (path.toString url)


# require all the formats, so they register themselves

require 'ruleset/tree-ruleset'
