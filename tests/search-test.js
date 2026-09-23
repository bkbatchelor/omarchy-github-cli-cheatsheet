const assert = require("assert")
const path = require("path")
const search = require(path.join(__dirname, "..", "GhCommandSearch.js"))

const items = [
  { category: "Core", command: "gh pr create", description: "Create a pull request" },
  { category: "Core", command: "gh pr list", description: "List pull requests in a repository" },
  { category: "GitHub Actions", command: "gh run list", description: "List recent workflow runs" },
  { category: "Core", command: "gh auth token", description: "Print the authentication token gh uses" },
  { category: "Alias", command: "gh co", description: "Alias for \"pr checkout\"" }
]

assert.deepStrictEqual(search.parseIndex(JSON.stringify(items)).items, items)
assert.strictEqual(search.parseIndex('{"error":"gh not found"}').error, "gh not found")
assert.ok(search.parseIndex("not json").error)

assert.strictEqual(search.filterCommands(items, "").length, 5)
assert.deepStrictEqual(search.filterCommands(items, "pr cre").map(i => i.command), ["gh pr create"])
assert.deepStrictEqual(search.filterCommands(items, "LIST").map(i => i.command), ["gh pr list", "gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "actions").map(i => i.command), ["gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "checkout").map(i => i.command), ["gh co"])
// Command-word matches win over description substrings ("pr" in "print").
assert.deepStrictEqual(search.filterCommands(items, "pr").map(i => i.command), ["gh pr create", "gh pr list"])
// With no command-word match, fall back to full-text matching.
assert.deepStrictEqual(search.filterCommands(items, "workflow").map(i => i.command), ["gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "authentication").map(i => i.command), ["gh auth token"])
assert.strictEqual(search.filterCommands(items, "nomatch").length, 0)
assert.strictEqual(search.filterCommands(null, "x").length, 0)

console.log("search-test: ok")
