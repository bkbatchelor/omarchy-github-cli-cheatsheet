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

// Every term must appear somewhere in the command, description, or category.
// Input order is preserved, so results stay grouped by category.
function filterCommands(items, query) {
  var values = Array.isArray(items) ? items : []
  var terms = queryTerms(query)
  var out = []

  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (!item || !item.command) continue

    var haystack = searchText(item)
    var matches = true
    for (var t = 0; t < terms.length; t++) {
      if (haystack.indexOf(terms[t]) < 0) {
        matches = false
        break
      }
    }

    if (matches) out.push(item)
  }

  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    parseIndex: parseIndex,
    queryTerms: queryTerms,
    filterCommands: filterCommands
  }
}
