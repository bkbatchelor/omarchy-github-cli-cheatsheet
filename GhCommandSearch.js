function parseIndex(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (Array.isArray(data)) return { items: data, error: "" }
    if (data && data.error) return { items: [], error: String(data.error) }
  } catch (e) {}
  return { items: [], error: "Could not read the gh command index" }
}

function queryTerms(query) {
  var text = String(query || "").trim().toLowerCase()
  return text ? text.split(/\s+/) : []
}

function searchText(item) {
  return (String(item.command || "") + " " + String(item.description || "") + " " + String(item.category || "")).toLowerCase()
}

function commandWords(item) {
  return String(item.command || "").toLowerCase().split(/[\s-]+/)
}

// A term matches a command when it is the start of one of its words, so
// "pr cre" finds "gh pr create" but "pr" doesn't match "gh auth token".
function matchesCommand(item, terms) {
  var words = commandWords(item)
  for (var t = 0; t < terms.length; t++) {
    var found = false
    for (var w = 0; w < words.length; w++) {
      if (words[w].indexOf(terms[t]) === 0) {
        found = true
        break
      }
    }
    if (!found) return false
  }
  return true
}

function matchesText(item, terms) {
  var haystack = searchText(item)
  for (var t = 0; t < terms.length; t++) {
    if (haystack.indexOf(terms[t]) < 0) return false
  }
  return true
}

// Commands whose words start with every term win. When none do, fall back to
// matching anywhere in the command, description, or category. Input order is
// preserved, so results stay grouped by category.
function filterCommands(items, query) {
  var values = Array.isArray(items) ? items : []
  var terms = queryTerms(query)
  var byCommand = []
  var byText = []

  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item || !item.command) continue

    if (matchesCommand(item, terms)) byCommand.push(item)
    else if (byCommand.length === 0 && matchesText(item, terms)) byText.push(item)
  }

  return byCommand.length > 0 ? byCommand : byText
}

if (typeof module !== "undefined") {
  module.exports = {
    parseIndex: parseIndex,
    queryTerms: queryTerms,
    filterCommands: filterCommands
  }
}
