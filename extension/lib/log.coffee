


console = Cc["@mozilla.org/consoleservice;1"].getService Ci.nsIConsoleService
exports.loggerFactory = loggerFactory = (module) -> (args...) ->
  console.logStringMessage "policeman: #{module}: #{args}"

