package main

import "core:fmt"
import "core:os"
import "core:strings"

in_git_repo :: proc() -> bool {
	state, _, _, err := os.process_exec(
		{command = {"/usr/bin/git", "rev-parse", "--is-inside-work-tree"}},
		context.temp_allocator,
	)

	if err != nil {
		return false
	}
	return state.exit_code == 0
}

get_staged_diff :: proc() -> (string, bool) {
	state, stdout, sterr, err := os.process_exec(
		{command = {"/usr/bin/git", "diff", "--cached"}},
		context.temp_allocator,
	)
	if err != nil {
		fmt.eprintfln("strudel: failed to run git diff: %v", err)
		return "", false
	}
	if state.exit_code != 0 {
		fmt.eprintfln("strudel: git diff failed: %s", string(sterr))
		return "", false
	}
	return strings.trim_space(string(stdout)), true
}

do_commit :: proc(message: string) -> bool {
	state, _, stderr, err := os.process_exec(
		{command = {"/usr/bin/git", "commit", "-m", message}},
		context.temp_allocator,
	)
	if err != nil {
		fmt.eprintfln("strudel: failed to run git commit: %v", err)
		return false
	}
	if state.exit_code != 0 {
		fmt.eprintfln("strudel: git commit failed: %s", string(stderr))
		return false
	}
	return true
}
