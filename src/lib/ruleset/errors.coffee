

exports.RulesetError = class RulesetError extends Error

exports.RulesetParserError = class RulesetParserError extends RulesetError
exports.WrongMagicError = class WrongMagicError extends RulesetParserError

