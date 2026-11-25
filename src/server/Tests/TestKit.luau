--!nonstrict
-- Zero-dependency test harness. Runs inside Studio, prints to the Output window, and never ships
-- a result to a live server (see Bootstrap.server.luau's Studio guard).

local TestKit = {}

local state = {
	passed = 0,
	failed = 0,
	failures = {},
}

function TestKit.describe(name: string, fn)
	print(("[tests] -- %s"):format(name))
	fn()
end

function TestKit.it(name: string, fn)
	local ok, err = pcall(fn)
	if ok then
		state.passed += 1
		print(("  ok    %s"):format(name))
	else
		state.failed += 1
		local message = ("%s :: %s"):format(name, tostring(err))
		state.failures[#state.failures + 1] = message
		warn(("  FAIL  %s"):format(message))
	end
end

function TestKit.expectEqual(actual, expected, label: string?)
	if actual ~= expected then
		error(
			("%s expected %s, got %s"):format(label or "value", tostring(expected), tostring(actual)),
			2
		)
	end
end

function TestKit.expectTrue(value, label: string?)
	if not value then
		error(label or "expected true", 2)
	end
end

function TestKit.expectFalse(value, label: string?)
	if value then
		error(label or "expected false", 2)
	end
end

function TestKit.expectAtLeast(actual: number, minimum: number, label: string?)
	if actual < minimum then
		error(("%s expected >= %s, got %s"):format(label or "value", tostring(minimum), tostring(actual)), 2)
	end
end

function TestKit.expectAtMost(actual: number, maximum: number, label: string?)
	if actual > maximum then
		error(("%s expected <= %s, got %s"):format(label or "value", tostring(maximum), tostring(actual)), 2)
	end
end

function TestKit.summary(): { passed: number, failed: number, failures: { string } }
	return {
		passed = state.passed,
		failed = state.failed,
		failures = state.failures,
	}
end

function TestKit.report()
	local total = state.passed + state.failed
	if state.failed == 0 then
		print(("[tests] PASSED %d/%d"):format(state.passed, total))
	else
		warn(("[tests] FAILED %d of %d"):format(state.failed, total))
		for _, failure in ipairs(state.failures) do
			warn("        " .. failure)
		end
	end
end

return TestKit
