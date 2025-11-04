import assert from "assert";

function mirrorWord(word) {
  return word
    .split("")
    .map((ch) =>
      ch === ch.toLowerCase()
        ? ch.toUpperCase()
        : ch.toLowerCase()
    )
    .reverse()
    .join("");
}

// Test case
const input = "fOoBar25";
const expected = "52RAbOoF";
const result = mirrorWord(input);

assert.strictEqual(result, expected);
console.log("✅ Test passed: fOoBar25 → 52RAbOoF");
