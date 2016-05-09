

Cu.import 'resource://gre/modules/osfile.jsm'


savefilepicker = Cc["@mozilla.org/filepicker;1"]
                 .createInstance(Ci.nsIFilePicker)
savefilepicker.init window,
                    l10n('preferences_user_rulesets_export_file_dialog'),
                    Ci.nsIFilePicker.modeSave
savefilepicker.appendFilter 'Policeman rules dump', '*.policeman.json'
savefilepicker.defaultString = 'persistent_rules.policeman.json'


{ manager } = require 'lib/ruleset/manager'


persistentRules = new RulesTree \
  '#persistent-rules', '#persistent-rules-search-box', 'user_persistent'

exportSelectionRadiogroup =
  init: ->
    @allRadio = $ '#export-all-rules'
    @selectedRadio = $ '#export-selected-rules'

    @allRadio.addEventListener 'RadioStateChange', ->
      $('#persistent-rules-container').hidden = @selected
    $('#persistent-rules-container').hidden = yes

exportButton =
  init: ->
    @$ = $ '#export-button'
    @$.addEventListener 'command', @onCommand.bind @

  onCommand: ->
    res = savefilepicker.show()
    return if res == Ci.nsIFilePicker.returnCancel
    savepath = savefilepicker.file.path

    if exportSelectionRadiogroup.allRadio.selected
      table = manager.get('user_persistent').toTable()
    else
      table = persistentRules.getSelectedTable()

    string = DeepLookupRSFileFormat::stringify table

    OS.File.writeAtomic(savepath, string, encoding: "utf-8").catch (e) ->
      log 'Error exporting rules into', savepath, ':', e
      # maybe TODO something a bit friendlier than alert
      alert l10n 'preferences_user_rulesets_export_failed_write', savepath

onLoad = ->
  if manager.enabled 'user_persistent'
    persistentRules.init()
    exportSelectionRadiogroup.init()
    exportButton.init()
  else
    $('#export-container').hidden = yes
    $('#persistent-ruleset-diabled-container').hidden = no
