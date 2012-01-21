/**
 * RegexpUnfail
 *
 * A utility to help compose and discuss regular expressions.
 *
 * Todo:
 * - real lint engine
 * - pretty printer
 * - facebook integration
 *   - keep track of who wrote what
 *   - adding comments
 *
 * Running:
 * opa-plugin-builder -o regexp_unfail_binding regexp_unfail_binding.js
 * opa --parser js-like regexp_unfail_binding.opp regexp_parser.opa regexp_printer.opa regexp_unfail.opa --
 */

import stdlib.themes.bootstrap
import stdlib.web.client

type regexp_result = {
  string regexp,
  string comment,
  intmap(string) true_positives,
  intmap(string) true_negatives
}

database intmap(regexp_result) /regexps

server exposed function my_log(obj) {
  Debug.warning(Debug.dump(obj))
}

function save_data(int id) {
  // convert #true_positives into an intmap
  (intmap(string) true_positives, _) = Dom.fold_deep(
    function (intmap(string), int) (dom el, (r, n)) {
      option(string) v = Dom.get_attribute(el, "str")
      match (v) {
        case {some:str}:
          (Map.add(n, str, r), n+1)
        case _ :
          (r, n)
      }
    },
    (Map.empty, 0),
    #true_positives
  )

  // convert #true_negatives into an intmap
  (intmap(string) true_negatives, _) = Dom.fold_deep(
    function (intmap(string), int) (dom el, (r, n)) {
      option(string) v = Dom.get_attribute(el, "str")
      match (v) {
        case {some:str}:
          (Map.add(n, str, r), n+1)
        case _ :
          (r, n)
      }
    },
    (Map.empty, 0),
    #true_negatives
  )

  regexp_result r = {
    regexp: Dom.get_value(#regexp),
    comment: Dom.get_content(#comment),
    true_positives: true_positives,
    true_negatives: true_negatives,
  }

  int id2 = if (id == 0) { Db.fresh_key(@/regexps); } else { id; }
  /regexps[id2] <- r

  Client.goto("/{id2}")
}

function resource display(regexp_result data, int id) {
  Resource.styled_page(
    "RegexpUnfail | compose",
    ["/resources/regexp_unfail.css"],
    <>
      <div class="container" onready={function(_){load_tests(data)}}>
        <div class="content">
          <section>
            <div class="page-header"><h1>Create a new Regular Expression</h1></div>
            <div class="row">
              <div class="span8 offset4">
                <div class="input">
                  <input
                    class="xxlarge"
                    type="text"
                    id=#regexp
                    placeholder="Enter a regular expression"
                    value={data.regexp}
                    onkeyup={
                      function(_){
                        check_regexp()
                        linter_run()
                      }
                    }/>
                </div>
                <br/>
              </div>
            </div>
            <div class="row">
              <div class="span4">
                <h3>Description</h3>
                <p>
                  Please explain what your regular expression is designed to match. This will help your reviewers suggest
                  test inputs.
                </p>
              </div>
              <div class="span8"><textarea rows="4" class="xxlarge" id=#comment>{data.comment}</textarea></div>
            </div>
            <div class="row">
              <div class="span4">
                <h3>Parser output</h3>
                <p>
                  For now, just some debugging info.
                </p>
              </div>
              <div class="span8">
                <div id=#parser_output/>
              </div>
            </div>
            <div class="row hidden" id=#lint>
              <div class="span4">
                <h3>Lint errors & warnings</h3>
                <p>
                  The automated rules have detected one or more violations.
                </p>
              </div>
              <div class="span8" id=#lint_rules/>
            </div>
            <div class="row">
              <div class="span4">
                <h3>Test input</h3>
              </div>
              <div class="span5 alert-message block-message success">
                <h3>True positives</h3>
                <div id=#true_positives>
                </div>
                <input type="text" id=#true_positive placeholder="enter a string which should match" onnewline={function(e) {append(#true_positives, #true_positive, true)}}/>
              </div>

              <div class="span5 alert-message block-message error">
                <h3>True negatives</h3>
                <div id=#true_negatives>
                </div>
                <input type="text" id=#true_negative placeholder="enter a string which should not match" onnewline={function(e) {append(#true_negatives, #true_negative, false)}}/>
              </div>
            </div>
            <div class="row">
              <div class="span8 offset4">
                <input type="submit" value="Save" class="btn primary" onclick={function(e){save_data(id)}}/>
              </div>
            </div>
          </section>
        </div>
      </div>
    </>
  )
}

function void load_tests(regexp_result data) {
  Map.iter(
    function(int _, string s) {
      #true_positives =+ get_result_div(s, true)
    },
    data.true_positives
  )
  Map.iter(
    function(int _, string s) {
      #true_negatives =+ get_result_div(s, false)
    },
    data.true_negatives
  )
  linter_run()
}

function bool contains(string haystack, string needle) {
  Option.is_some(String.strpos(needle, haystack))
}

function void lint_fix_rule1() {
  string regexp = Dom.get_value(#regexp)
  string r2 = String.replace(".", "\\.", regexp)
  Dom.set_value(#regexp, r2)

  // rerun checks
  check_regexp()
  linter_run()
}

function void linter_run() {
  // TODO: run a real lint engine
  string regexp = Dom.get_value(#regexp)
  l =
    if (contains(regexp, ".com") && (contains(regexp, "\\.com") == false)) {
      {some:
        <div id="lint_rule1" class="alert-message block-message warning span8">
          <p><span class="icon32 icon-alert"></span> <strong>LINT RULE 1</strong><br/>
          It seems you are trying to match a URL. You should use <strong>\\.</strong> instead of <strong>.</strong><br/></p>
          <div class="alert-actions">
            <a href="#" onclick={function(_){lint_fix_rule1()}} class="btn small">Fix regular expression</a>
          </div>
        </div>
      }
    } else {
      {none}
    }
  if (Option.is_some(l)) {
    if (Dom.is_empty(Dom.select_id("lint_rule1"))) {
      Dom.remove_class(#lint, "hidden")
      Dom.put_at_end(#lint_rules, Dom.of_xhtml(Option.get(l)))
      void
    }
    void
  } else {
    Dom.add_class(#lint, "hidden")
    Dom.remove_content(#lint_rules)
    void
  }
  void
}

function void append(list, item, expected) {
  *list =+ get_result_div(Dom.get_value(item), expected)
  Dom.set_value(item, "")
}

client regexp_test = %%regexp_unfail_binding.regexp_test%%

client function xhtml get_result_div(string str, bool expected) {
  string regexp = Dom.get_value(#regexp)
  result = regexp_test(regexp, str)
  id = Dom.fresh_id()
  str2 = if (str == "") { <i>empty string</i> } else { <>{str}</> }

  close = <a href="#" onclick={function(_){ Dom.remove(Dom.select_id(id)) }} class="close">×</a>

  if (expected && result) {
    <div id={id} str="{str}"><span class="label success">OK</span> {str2} {close}</div>
  } else if (expected==false && result==false) {
    <div id={id} str="{str}"><span class="label success">OK</span> {str2} {close}</div>
  } else {
    <div id={id} str="{str}"><span class="label warning">FAIL</span> <strong>{str2}</strong> {close}</div>
  }
}

client function void check_regexp() {
  // run regexp on true_positives and true_negatives and colorize the output
  x = Dom.fold_deep(
    function xhtml (dom el, xhtml r) {
      option(string) v = Dom.get_attribute(el, "str")
      match (v) {
        case {some:str}:
        <>
          {r}
          {get_result_div(str, true)}
        </>
        case _ :
          r
      }
    },
    <></>,
    #true_positives
  )
  Dom.put_inside(#true_positives, Dom.of_xhtml(x))

  x = Dom.fold_deep(
    function xhtml (dom el, xhtml r) {
      option(string) v = Dom.get_attribute(el, "str")
      match (v) {
        case {some:str}:
        <>
          {r}
          {get_result_div(str, false)}
        </>
        case _ :
          r
      }
    },
    <></>,
    #true_negatives
  )
  Dom.put_inside(#true_negatives, Dom.of_xhtml(x))

  // Run the parser
  string regexp = Dom.get_value(#regexp)
  #parser_output = RegexpPrinter.pretty_print(RegexpParser.parse(regexp))
  void
}

function resource start(Uri.relative uri) {
  match (uri) {
    case {path:{nil} ...}:
      regexp_result data = {regexp:"", comment:"", true_positives:Map.empty, true_negatives:Map.empty}
      display(data, 0)
    case {path:{~hd, tl:[]} ...}:
      int id = Int.of_string(hd)
      regexp_result data = /regexps[id]
      display(data, id)
    case {~path ...}:
      my_log(path)
      Resource.styled_page("hmm", [], <>hi</>)
  }
}

Server.start(
  Server.http,
  [
    {resources: @static_include_directory("resources")},
    {dispatch: start}
  ]
)