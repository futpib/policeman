
{
  foreign: foreignPrefs
} = require 'lib/prefs'


# Mirrors addon-sdk/l10n/locale#getPreferedLocales
exports.prefered_locales = prefered_locales = do ->
  foreignPrefs.define PREF_MATCH_OS_LOCALE = "intl.locale.matchOS", default: yes
  foreignPrefs.define PREF_SELECTED_LOCALE = "general.useragent.locale", default: ''
  foreignPrefs.define PREF_ACCEPT_LANGUAGES = "intl.accept_languages", default: ''

  locales = []

  addLocale = (locale) ->
    locale = locale.trim()
    locales.push locale unless locale in locales

  if foreignPrefs.get PREF_MATCH_OS_LOCALE
    localeService = Cc["@mozilla.org/intl/nslocaleservice;1"]
                    .getService Ci.nsILocaleService
    osLocale = localeService.getLocaleComponentForUserAgent()
    addLocale osLocale

  browserUiLocale = foreignPrefs.get PREF_SELECTED_LOCALE
  if browserUiLocale
    addLocale browserUiLocale

  contentLocales = foreignPrefs.get PREF_ACCEPT_LANGUAGES
  if contentLocales
    addLocale locale for locale in contentLocales.split ','

  addLocale "en-US"

  # also append short versions of all culture codes
  for locale in locales
    [language, region] = locale.split '-'
    addLocale language if region and language not in locales

  return locales

bundle = Services.strings.createBundle \
      'chrome://policeman/locale/policeman.properties'

onShutdown.add Services.strings.flushBundles

exports.l10n = (s, args...) ->
    try
      return bundle.formatStringFromName s, args, args.length
    catch e
      msg = "l10n #{s}, #{JSON.stringify args} failed,
             check browser console for exact reason"
      log "l10n", s, args, 'failed with the following error:', e
      return msg
