const assert = require("assert")
const path = require("path")
const search = require(path.join(__dirname, "..", "GhCommandSearch.js"))

const items = [
  { category: "Core", command: "gh pr create", description: "Create a pull request" },
  { category: "Core", command: "gh pr list", description: "List pull requests in a repository" },
  { category: "GitHub Actions", command: "gh run list", description: "List recent workflow runs" },
  { category: "Alias", command: "gh co", description: "Alias for \"pr checkout\"" }
]

assert.deepStrictEqual(search.parseIndex(JSON.stringify(items)).items, items)
assert.strictEqual(search.parseIndex('{"error":"gh not found"}').error, "gh not found")
assert.ok(search.parseIndex("not json").error)

assert.strictEqual(search.filterCommands(items, "").length, 4)
assert.deepStrictEqual(search.filterCommands(items, "pr cre").map(i => i.command), ["gh pr create"])
assert.deepStrictEqual(search.filterCommands(items, "LIST").map(i => i.command), ["gh pr list", "gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "actions").map(i => i.command), ["gh run list"])
assert.deepStrictEqual(search.filterCommands(items, "checkout").map(i => i.command), ["gh co"])
assert.strictEqual(search.filterCommands(items, "nomatch").length, 0)
assert.strictEqual(search.filterCommands(null, "x").length, 0)

console.log("search-test: ok")
