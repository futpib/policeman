
{
    Cc,
    Ci,
} = require 'chrome'

self = require 'sdk/self'

ioService = Cc["@mozilla.org/network/io-service;1"]
    .getService Ci.nsIIOService
fileProtocol = Cc["@mozilla.org/network/protocol;1?name=file"]
    .getService Ci.nsIFileProtocolHandler
scriptableStream = Cc["@mozilla.org/scriptableinputstream;1"]
    .getService Ci.nsIScriptableInputStream
directoryService = Cc["@mozilla.org/file/directory_service;1"]
    .getService Ci.nsIProperties
utf8Converter = Cc["@mozilla.org/intl/utf8converterservice;1"]
    .getService Ci.nsIUTF8ConverterService

exports.path = path = new class
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

  localFileRe = /// # used to determine if we need to prepend 'file://'
    ^(\/|[A-Z]+:(\\|\/){1,2}) # match '/', 'A://a', 'A:\a'
    (?![A-Z]+:(\\|\/){1,2})   # but not 'file://A:\a'
  ///i

  toURI: (x) ->
    if x instanceof Ci.nsIURI
      return x.clone()
    if x instanceof Ci.nsIFile
      return ioService.newFileURI x
    if typeof x == 'string'
      if localFileRe.test x
        x = 'file://' + x
      return ioService.newURI x, null, null
    throw new Error "path.toURI: Can't make URI from #{base} (type: #{typeof base})"

  toFile: (x) ->
    if x instanceof Ci.nsIURI
      return fileProtocol.getFileFromURLSpec x.spec
    if x instanceof Ci.nsIFile
      return x.clone()
    if typeof x == 'string'
      if localFileRe.test x
        x = 'file://' + x
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
  defaults: ioService.newURI(self.data.url('defaults/'), null, null)

  NEW_DIR_PERMISSIONS = 0b111100100
                        # rwxr--r-- permissions

  profileDir = directoryService.get "ProfD", Ci.nsIFile

  # policeman folder in firefox's profile directory
  policemanDir = profileDir.clone()
  policemanDir.append 'policeman'
  unless policemanDir.exists() and policemanDir.isDirectory()
    policemanDir.create Ci.nsIFile.DIRECTORY_TYPE, NEW_DIR_PERMISSIONS

  profile: @::toURI policemanDir

  # folder for installed rulesets in firefox's profile directory
  rulesetsDir = policemanDir.clone()
  rulesetsDir.append 'rulesets'
  unless rulesetsDir.exists() and rulesetsDir.isDirectory()
    rulesetsDir.create Ci.nsIFile.DIRECTORY_TYPE, NEW_DIR_PERMISSIONS

  rulesets: @::toURI rulesetsDir

  content: 'chrome://policeman/content'
  skin   : 'chrome://policeman/skin'
  locale : 'chrome://policeman/locale'

exports.file =
  read: (uri) ->
    channel = ioService.newChannelFromURI path.toURI uri
    input = channel.open()
    scriptableStream.init input
    str = scriptableStream.read input.available()
    str = utf8Converter.convertURISpecToUTF8 str, "UTF-8"
    scriptableStream.close()
    input.close()
    return str
