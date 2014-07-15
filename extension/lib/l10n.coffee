
exports.locale = locale = Cc["@mozilla.org/chrome/chrome-registry;1"]
          .getService Ci.nsIXULChromeRegistry
          .getSelectedLocale 'global'


bundle = Services.strings.createBundle \
      'chrome://policeman/locale/policeman.properties'

onShutdown.add Services.strings.flushBundles

exports.l10n = (s, args...) ->
    try
      return bundle.formatStringFromName s, args, args.length
    catch e
      msg = "l10n #{s}, #{JSON.stringify args}: error: #{e}"
      log msg
      return msg
