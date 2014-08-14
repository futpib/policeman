

ioService = Cc["@mozilla.org/network/io-service;1"]
    .getService Ci.nsIIOService
fileProtocol = Cc["@mozilla.org/network/protocol;1?name=file"]
    .getService Ci.nsIFileProtocolHandler
scriptableStream = Cc["@mozilla.org/scriptableinputstream;1"]
    .getService Ci.nsIScriptableInputStream
directoryService = Cc["@mozilla.org/file/directory_service;1"]
    .getService Ci.nsIProperties

exports.path = path =
  join: (base, paths...) -> # preserves base type, assumes paths are just strings
    if base instanceof Ci.nsIFile
      baseClone = base.clone()
      for p in paths
        baseClone.append p
      return baseClone
    if base instanceof Ci.nsIURI
      return ioService.newURI (this.join base.spec, paths...), null, null
    if typeof base == 'string'
      for p in paths
        if not base.endsWith('/')
          base += '/'
        base += p
      return base
    throw new Error "path.join: wrong base path type: #{typeof base}"

  toURI: (x) ->
    if x instanceof Ci.nsIURI
      return x.clone()
    if x instanceof Ci.nsIFile
      return ioService.newFileURI x
    if typeof x == 'string'
      return ioService.newURI x, null, null
    throw new Error "path.toURI: Can't make URI from #{base} (type: #{typeof base})"

  toFile: (x) ->
    if x instanceof Ci.nsIURI
      return fileProtocol.getFileFromURLSpec x.spec
    if x instanceof Ci.nsIFile
      return x.clone()
    if typeof x == 'string'
      return fileProtocol.getFileFromURLSpec x
    throw new Error "path.toFile: Can't make File from #{base} (type: #{typeof base})"

  toString: (x) ->
    if x instanceof Ci.nsIURI
      return x.spec
    if x instanceof Ci.nsIFile
      return @.toURI(x).spec
    if typeof x == 'string'
      return x
    throw new Error "path.toString: Can't get url string from #{base} (type: #{typeof base})"

  # 'defaults' folder of extension
  defaults: ioService.newURI(addonData.resourceURI.spec + 'defaults/', null, null)

  # policeman folder in firefox's profile directory
  profile: do ->
    localDir = directoryService.get "ProfD", Ci.nsIFile
    localDir.append 'policeman'
    unless localDir.exists() and localDir.isDirectory()
      localDir.create Ci.nsIFile.DIRECTORY_TYPE, 0b111111100
                                                 # rwxrwxr-- permissions
    return ioService.newFileURI localDir

  content: 'chrome://policeman/content'
  skin   : 'chrome://policeman/skin'
  locale : 'chrome://policeman/locale'

exports.file =
  read: (uri) ->
    log uri.spec
    channel = ioService.newChannelFromURI path.toURI uri
    input = channel.open()
    scriptableStream.init input
    str = scriptableStream.read input.available()
    scriptableStream.close()
    input.close()
    return str
