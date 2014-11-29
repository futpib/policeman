
{
  foreign: foreignPrefs
} = require 'prefs'


# Mirrors addon-sdk/l10n/locale#getPreferedLocales
exports.locale = locale = do ->
  foreignPrefs.define PREF_MATCH_OS_LOCALE = "intl.locale.matchOS", default: yes
  foreignPrefs.define PREF_SELECTED_LOCALE = "general.useragent.locale", default: ''
  foreignPrefs.define PREF_ACCEPT_LANGUAGES = "intl.accept_languages", default: ''

  if foreignPrefs.get PREF_MATCH_OS_LOCALE
    localeService = Cc["@mozilla.org/intl/nslocaleservice;1"]
                    .getService(Ci.nsILocaleService)
    return localeService.getLocaleComponentForUserAgent()

  if browserUiLocale = foreignPrefs.get PREF_SELECTED_LOCALE
    return browserUiLocale

  if contentLocales = foreignPrefs.get PREF_ACCEPT_LANGUAGES
    return contentLocales.split(",")[0].trim()

  return "en-US"

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
