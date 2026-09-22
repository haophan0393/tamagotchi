## gdUnit4 test runner — the single entry point used by CI and by /smoke-check.
##
## Usage (the command pinned in .claude/docs/technical-preferences.md):
##     godot --headless --script tests/gdunit4_runner.gd
##
## Delegating wrapper, not a reimplementation. It instantiates gdUnit4's own
## [GdUnitTestCIRunner] — the same class [code]addons/gdUnit4/bin/GdUnitCmdTool.gd[/code]
## uses — so runner behaviour always tracks the installed addon version.
##
## Two things this wrapper adds, both required for the pinned command to work:
##
## 1. [b]--ignoreHeadlessMode[/b]. gdUnit4 v6 refuses to run under
##    [code]--headless[/code] by default and exits with
##    RETURN_ERROR_HEADLESS_NOT_SUPPORTED. Our suites are pure logic tests with no
##    UI interaction, so the restriction does not apply to us. Godot does not deliver
##    [code]InputEvent[/code]s in headless mode — if a future suite needs real input,
##    it belongs in tests/integration/ and must run on a non-headless CI job.
## 2. [b]Default suite paths[/b], so the pinned command needs no arguments. Any
##    argument supplied on the command line replaces these defaults entirely.
##
## Exit codes are gdUnit4's own: 0 success, non-zero failure. CI relies on this.
extends SceneTree

## Suites run when no paths are given on the command line.
const DEFAULT_SUITE_PATHS: Array[String] = ["tests/unit", "tests/integration"]

const RUNNER_SCRIPT := "res://addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd"

## gdUnit4's CmdArgumentParser discards every token up to and including the one
## containing its tool name, because it expects to be handed a raw
## OS.get_cmdline_args() that still has the engine's own flags on the front.
## We hand it a synthetic vector, so it must start with this sentinel or the
## parser eats the whole thing and prints its help screen instead of running.
const PARSER_SENTINEL := "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

var _runner: Node


func _initialize() -> void:
	var runner_script: GDScript = load(RUNNER_SCRIPT)
	if runner_script == null:
		push_error(
			"gdUnit4 not found at %s. Install it before running tests — see tests/README.md."
			% RUNNER_SCRIPT
		)
		quit(1)
		return

	_runner = runner_script.new()
	_runner._debug_cmd_args = _build_args()
	root.add_child(_runner)


## Builds the argument vector handed to the gdUnit4 CI runner.
##
## Returns the user's own arguments when any were supplied after a [code]--[/code]
## separator, otherwise the default suite set. The vector always opens with
## [constant PARSER_SENTINEL] and always ends with [code]--ignoreHeadlessMode[/code].
func _build_args() -> PackedStringArray:
	var args := PackedStringArray([PARSER_SENTINEL])
	var user_args := OS.get_cmdline_user_args()

	if user_args.is_empty():
		for suite_path: String in DEFAULT_SUITE_PATHS:
			args.append("-a")
			args.append(suite_path)
		# Report every failure rather than stopping at the first one; a CI run
		# should surface the whole picture in a single pass.
		args.append("-c")
	else:
		args.append_array(user_args)

	args.append("--ignoreHeadlessMode")
	return args


func _finalize() -> void:
	if _runner != null:
		_runner.queue_free()
