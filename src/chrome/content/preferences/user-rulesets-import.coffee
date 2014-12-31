

Cu.import 'resource://gre/modules/osfile.jsm'


filepicker = Cc["@mozilla.org/filepicker;1"]
             .createInstance(Ci.nsIFilePicker)
filepicker.init window,
                    l10n('preferences_user_rulesets_export_file_dialog'),
                    Ci.nsIFilePicker.modeOpen
filepicker.appendFilter 'Policeman rules dump', '*.policeman.json'
filepicker.appendFilter 'JSON', '*.json'
filepicker.appendFilter 'Any file', '*'


{ manager } = require 'ruleset/manager'


{
  zip
} = require 'utils'


loadedRules = new RulesTree \
  '#loaded-rules', '#loaded-rules-search-box', []

dumpLoader =
  init: ->
    $('#load-file-button').addEventListener 'command', @loadFile.bind @

  loadFile: ->
    res = filepicker.show()
    return if res == Ci.nsIFilePicker.returnCancel
    loadpath = filepicker.file.path

    decoder = new TextDecoder
    # TODO progressbar or something
    OS.File.read(loadpath).then ((array) =>
      @_loadString decoder.decode array
      $('#loaded-file-label').value = loadpath
    ), ((error) ->
      log "Error reading file", loadpath, ':', error
      alert l10n 'preferences_user_rulesets_import_reading_file_failed', loadpath
    )

  _loadString: (string) ->
    try
      table = DeepLookupRSFileFormat::parse string
    catch e
      log 'Error parsing dump data:', e
      alert l10n 'preferences_user_rulesets_import_parsing_failed'

    loadedRules.setDataSource table

    $('#loaded-rules-container').hidden = no

    statusIndicator.setStatus \
      text: l10n 'preferences_user_rulesets_import_file_loaded'


importSelection =
  init: ->
    @allRadio = $ '#import-all-rules'
    @selectedRadio = $ '#import-selected-rules'

  getSelectedRules: ->
    if @allRadio.selected
      return loadedRules.toTable()
    else
      return loadedRules.getSelectedTable()


conflictResolution = new class
  bindShouldImport = (btn, f) ->
    btn.addEventListener 'RadioStateChange', =>
      if btn.selected
        @shouldImport = f

  init: ->
    @_newRadio = $ '#conflict-resolution-prefer-new'
    @_existingRadio = $ '#conflict-resolution-prefer-existing'
    @_permissiveRadio = $ '#conflict-resolution-prefer-permissive'
    @_restrictiveRadio = $ '#conflict-resolution-prefer-restrictive'

    bindShouldImport @_newRadio, -> yes
    bindShouldImport @_existingRadio, -> no
    bindShouldImport @_permissiveRadio, ([_o, _d, _t, decision]) -> decision
    bindShouldImport @_restrictiveRadio, ([_o, _d, _t, decision]) -> not decision

  shouldImport: -> yes


importButton =
  init: ->
    @$ = $ '#import-button'
    @$.addEventListener 'command', @onCommand.bind @

  onCommand: ->
    return unless persistent = manager.get 'user_persistent'

    if loadedRules.toTable().length == 0
      dumpLoader.loadFile()
      return

    import_ = (o, d, t, decision) ->
      if decision
        persistent.allow o, d, t
      else
        persistent.reject o, d, t

    table = importSelection.getSelectedRules()

    stats =
      selected: table.length
      imported: 0

    for rule in table
      [o, d, t, decision] = rule
      if null == persistent.lookup o, d, t # no such rule exists
        import_ o, d, t, decision
        stats.imported += 1
      else # conflict found
        if conflictResolution.shouldImport rule
          import_ o, d, t, decision
          stats.imported += 1

    statusIndicator.setStatus \
      text: l10n 'preferences_user_rulesets_imported_rules_count', \
                  stats.imported, stats.selected


statusIndicator =
  init: ->
    @_statusLabel = $ '#import-status-label'
    @_statusLabel.addEventListener 'click', -> @value = ''
  setStatus: (description) ->
    {
      text
    } = description
    @_statusLabel.value = text


onLoad = ->
  if manager.enabled 'user_persistent'
    loadedRules.init()
    $('#loaded-rules-container').hidden = yes
    dumpLoader.init()
    importSelection.init()
    conflictResolution.init()
    importButton.init()
    statusIndicator.init()
  else
    $('#import-container').hidden = yes
    $('#persistent-ruleset-diabled-container').hidden = no
