
exports.RuleSet = class RuleSet # Base class for rulesets
  getMetadata: -> {
      id: @id
      version: @version

      # Localized strings for ui
      name: @name
      description: @description

      homepage: @homepage

      # Possible values: 'mixed', 'permissive', 'restrictive'. A tip for user.
      permissiveness: @permissiveness or 'mixed'
    }

  # returns true for accept, false for reject and null for undecided
  check: (origin, destination, context) ->
    return null
