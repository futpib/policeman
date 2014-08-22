
{ path, file } = require 'file'

{ TreeRS } = require 'ruleset/tree-ruleset'


exports.rulesetFromString = rulesetFromString = (str, sourceUrl) ->
  new TreeRS str, sourceUrl

exports.rulesetFromLocalUrl = rulesetFromLocalUrl = (url) ->
  rulesetFromString (file.read url), (path.toString url)

