const assert = require("assert")
const path = require("path")
const search = require(path.join(__dirname, "..", "GhCommandSearch.js"))

const items = [
  { category: "auth", command: "gh auth token", description: "Print the authentication token gh uses" },
  { category: "pr", command: "gh pr create", description: "Create a pull request" },
  { category: "pr", command: "gh pr list", description: "List pull requests in a repository" },
  { category: "run", command: "gh run list", description: "List recent workflow runs" }
]

assert.deepStrictEqual(search.parseIndex(JSON.stringify(items)).items, items)
assert.strictEqual(search.parseIndex('{"error":"gh not found"}').error, "gh not found")
assert.ok(search.parseIndex("not json").error)

assert.strictEqual(search.filterCommands(items, "").length, 4)
assert.deepStrictEqual(search.filterCommands(items, "pr cre").map(i => i.command), ["gh pr create"])
assert.deepStrictEqual(search.filterCommands(items, "LIST").map(i => i.command), ["gh pr list", "gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "recent").map(i => i.command), ["gh run list"])
// Command-word matches win over description substrings ("pr" in "print").
assert.deepStrictEqual(search.filterCommands(items, "pr").map(i => i.command), ["gh pr create", "gh pr list"])
// With no command-word match, fall back to full-text matching.
assert.deepStrictEqual(search.filterCommands(items, "workflow").map(i => i.command), ["gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "authentication").map(i => i.command), ["gh auth token"])
assert.strictEqual(search.filterCommands(items, "nomatch").length, 0)
assert.strictEqual(search.filterCommands(null, "x").length, 0)

console.log("search-test: ok")
