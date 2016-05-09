
self = require 'sdk/self'

{
    getPreferedLocales
} = require 'sdk/l10n/locale'

{
    get
} = require 'sdk/l10n'


exports.prefered_locales = getPreferedLocales()

exports.l10n = get
