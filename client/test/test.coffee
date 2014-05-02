buster = if window?.buster? then window.buster else require("buster")
assert = buster.assert
test = buster.testCase

test "Tests Sanity Check ",
  "tests pass": ->
    assert(true)

  # "tests fail": ->
  #   assert(false)
