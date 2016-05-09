
console.warn '`log` module is depricated, use standart `console` instead'

log = console.log.bind console
log.debug = console.debug.bind console
log.info  = console.info.bind console
log.warn  = console.warn.bind console
log.error = console.error.bind console

module.exports = log

