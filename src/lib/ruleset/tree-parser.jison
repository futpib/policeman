
%{
var nodes = require('ruleset/tree-nodes');
for (var name in nodes) {
  this[name] = nodes[name];
}
var requestInfo = require('request-info');
var errors = require('ruleset/errors');

var config = {
  'default': {
    Map: Map,
    // Map actually stores entries in insertion order, so it's a reasonable
    // data structure to use
    // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map/entries
  },
  'user': {},
  reset: function() { this.user = {}; },
  get: function (name) {
    if (name in this.user) {
      return this.user[name];
    } else {
      return this['default'][name];
    }
  },
  set: function (dict) {
    for (var k in dict) {
      this.user[k] = dict[k];
    }
  }
}
parser.config = config

var indentation = {
  reset: function () {
    this.current = 0;
    this.last = 0;
  },
  indent: function () { this.current++; },
  blank: function () { this.current = 0; },
  yieldToken: function () {
    if (this.current > this.last) {
      this.last++;
      return 'INDENT';
    } else if (this.current < this.last) {
      this.last--;
      return 'UNINDENT';
    }
    return null;
  },
};

var component = {
  defaults: ['schemeType', 'host', 'path'],
  precedence: [
    'schemeType',
    'scheme',
    'username',
    'password',
    'userPass',
    'host',
    'port',
    'hostPort',
    'prePath',
    'path',
    'spec',
    'contentType',
    'mime',
  ],
  // Components that don't belong to origin or destination uri.
  // Predicate on these components consist of a single test (without any ->)
  single: requestInfo.ContextInfo.prototype.components,
  // Components that support lookup, bare string on these will be parsed as
  // InTest not EqTest.
  list: ['classList'],

  reset: function () {
    this.stack = [];
  },
  push: function (c) {
    if (c) {
      this.stack.push(c);
    } else {
      let currentComponent = this.get();
      for (let i = this.precedence.indexOf(currentComponent)+1;
           i < this.precedence.length;
           i++) {
        if (this.defaults.indexOf(this.precedence[i]) != -1) {
          this.stack.push(this.precedence[i]);
          return;
        }
      }
    }
  },
  pop: function () { return this.stack.pop(); },
  get: function () { return this.stack[this.stack.length-1]; },
  isSingle: function () { return this.single.indexOf(this.get()) != -1; },
  isList: function () { return this.list.indexOf(this.get()) != -1; },
};

var stats = {
  reset: function () { this.acceptCount = this.rejectCount = 0; },
  getPermissiveness: function () {
    if (this.acceptCount && this.rejectCount) {
      return 'mixed';
    } else if (this.rejectCount) {
      return 'restrictive';
    } else {
      return 'permissive';
    }
  },
}

// Hook before parser.parse to reset our state
var originalParse = parser.parse;
parser.parse = function () {
  config.reset();
  indentation.reset();
  component.reset();
  stats.reset();

  return originalParse.apply(parser, arguments);
}

%}

%lex

// state for parsing the indentation
%x indent
// state for unindenting at EOF (because you can't unput(EOF))
%x final_unindent

%%

<indent>"  "      { indentation.indent(); }
<indent>\r?\n     { indentation.blank(); }
<indent>.         {
  this.unput(yytext);
  var t = indentation.yieldToken();
  if (t)
    return t;
  this.begin('INITIAL');
}
<indent><<EOF>>   {
  this.unput('x'); // put anything just to keep parser working
  this.begin('final_unindent');
}

<final_unindent>. {
  var t = indentation.yieldToken();
  if (t) {
    this.unput(yytext);
    return t;
  }
  this.begin('INITIAL');
}

\r?\n            { this.unput(yytext); this.begin('indent') }

":"              { return 'COLON' }

"{"              { return 'LBRACE' }
"}"              { return 'RBRACE' }

"rules:"         { return 'RULES_SECTION_START' }

"->"             { return 'ARROW' }
"*"              { return 'ASTERISK' }

"["              { return 'LBRACKET' }
"]"              { return 'RBRACKET' }

"("              { return 'LPAREN' }
")"              { return 'RPAREN' }
"|"              { return 'OR' }
%right OR
"!"              { return 'NOT' }

"ACCEPT"         { return 'ACCEPT' }
"REJECT"         { return 'REJECT' }
"RETURN"         { return 'RETURN' }

[0-9]+\.[0-9]+   { return 'FLOAT' }
[0-9]+           { return 'INTEGER' }

[a-zA-Z_\.\$-][a-zA-Z0-9_\.\$\&-]*  { return 'STRING' }
\&[a-zA-Z0-9_\.\$\&-]+\;       { return 'L10N_STRING' }
\"(\\.|[^"])*\"                { return 'QUOTED_STRING' }
\'(\\.|[^'])*\'                { return 'SINGLE_QUOTED_STRING' }
\/(\\\\.|[^\/])*\/[gimy]*      { return 'REGEXP' }

(\#|\/\/)[^\n]*  { /* skip block comments */ }
\s               { /* skip spaces */ }

<<EOF>>          { return 'EOF' }

/lex

%start start

%%

start
  : magic dict_body EOF
    {
      $2.permissiveness = stats.getPermissiveness();
      return $2;
    }
;

magic
  : string COLON string
    {
      if (($1 !== 'magic') || ($3 !== 'policeman_ruleset')) {
        throw new errors.WrongMagicError(
          'Expected "magic: policeman_ruleset" got "'
          + JSON.stringify($1) + ': ' + JSON.stringify($3) + '".');
      }
    }
;

dict_body
  : string COLON value
    { $$ = {}; $$[$1] = $3; }
  | string COLON value dict_body
    { $4[$1] = $3; $$ = $4; }
  | RULES_SECTION_START rule_set
    { $$ = { rules: $2 }; }
;

dict
  : scope dict_body unscope
    { $$ = $2; }
;

rule_set_body
  : predicate COLON consequent
    { $$ = [[$1, $3]]; }
  | predicate COLON consequent rule_set_body
    { $4.unshift([$1, $3]); $$ = $4; }
;

rule_set
  : scope component rule_set_body unscope
    {
      $$ = new (config.get('Map'))($3);
      component.pop();
    }
  |
    {
      $$ = new (config.get('Map'))();
    }
;

component
  : LBRACKET string RBRACKET
    { component.push($2); }
  |
    { component.push(); }
;

consequent
  : decision
  | rule_set
;

predicate
  : test ARROW test
    {
      if (component.isSingle()) {
        throw new Error(
          "Parse Error: Can't use (->)-predicate with component '"
          + component.get() + "'."
        );
      }
      $$ = new OrigDestPredicate(component.get(), $1, $3);
    }
  | test
    {
      if (!component.isSingle()) {
        throw new Error(
          "Parse Error: Can't use single-test predicate with component '"
          + component.get() + "'."
        );
      }
      $$ = new ContextPredicate(component.get(), $1);
    }
;

value
  : dict
  | string
  | number
;

number
  : float
  | integer
;

test
  : string_test
  | starts_ends_test
  | contains_test
  | regexp_test
  | port_test
  | or_test
  | not_test
  | empty_test
;

empty_test
  :
    { $$ = new ConstantTrueTest(); }
;

not_test
  : NOT test
    { $$ = new NegateTest($2); }
;

or_test
  : LPAREN or_test_body RPAREN
    { $$ = new OrTest($2); }
;

or_test_body
  : test OR or_test_body
    { $3.unshift($1); $$ = $3; }
  | test
    { $$ = [$1]; }
;

string_test
  : string
    {
      if (component.isList()) {
        $$ = new InTest($1);
      } else {
        $$ = new EqTest($1);
      }
    }
;

port_test
  : integer
    { $$ = new PortTest($1); }
;

starts_ends_test
  : string ASTERISK string
    { $$ = new StartsEndsTest($1, $3); }
  | ASTERISK string
    { $$ = new StartsEndsTest(null, $2); }
  | string ASTERISK
    { $$ = new StartsEndsTest($1, null); }
  | ASTERISK
    { $$ = new ConstantTrueTest(); }
;

contains_test
  : ASTERISK string ASTERISK
    { $$ = new ContainsTest($2); }
;

regexp_test
  : regexp
    { $$ = new RegExpTest($1); }
;

scope
  : INDENT
  | LBRACE
;

unscope
  : UNINDENT
  | RBRACE
;

regexp
  : REGEXP
    {
      var parts = $1.split("/");
      var pattern = parts[1], flags = parts[2];
      $$ = new RegExp(pattern, flags);
    }
;

integer
  : INTEGER
    { $$ = parseInt($1); }
;

float
  : FLOAT
    { $$ = parseFloat($1); }
;

string
  : STRING
    { $$ = $1; }
  | L10N_STRING
    { $$ = new L10nLookup($1.slice(1,-1)); }
  | QUOTED_STRING
    { $$ = JSON.parse($1); }
  | SINGLE_QUOTED_STRING
    { $$ = JSON.parse($1); }
;

decision
  : ACCEPT
    {
      stats.acceptCount += 1;
      $$ = true;
    }
  | REJECT
    {
      stats.rejectCount += 1;
      $$ = false;
    }
  | RETURN
    { $$ = null; }
;


