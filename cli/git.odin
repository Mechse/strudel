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

get_staged_diff_tier_1 :: proc() -> (string, bool) {
	state, stdout, sterr, err := os.process_exec(
		{command = {"/usr/bin/git", "diff", "--cached"}},
		context.temp_allocator,
	)
	if err != nil {
		fmt.eprintfln("saft: failed to run git diff: %v", err)
		return "", false
	}
	if state.exit_code != 0 {
		fmt.eprintfln("saft: git diff failed: %s", string(sterr))
		return "", false
	}
	return strings.trim_space(string(stdout)), true
}


get_staged_diff_tier_2 :: proc() -> (string, bool) {
	state_stat, stdout_stat, sterr_stat, err_stat := os.process_exec(
		{command = {"/usr/bin/git", "diff", "--cached", "--stat"}},
		context.temp_allocator,
	)
	if err_stat != nil {
		fmt.eprintfln("saft: failed to run git diff: %v", err_stat)
		return "", false
	}
	if state_stat.exit_code != 0 {
		fmt.eprintfln("saft: git diff failed: %s", string(sterr_stat))
		return "", false
	}
	stat := strings.trim_space(string(stdout_stat))


	state_minimal, stdout_minimal, sterr_minimal, err_minimal := os.process_exec(
		{command = {"/usr/bin/git", "diff", "--cached", "--unified=0"}},
		context.temp_allocator,
	)
	if err_minimal != nil {
		fmt.eprintfln("saft: failed to run git diff: %v", err_minimal)
		return "", false
	}
	if state_minimal.exit_code != 0 {
		fmt.eprintfln("saft: git diff failed: %s", string(sterr_minimal))
		return "", false
	}
	minimal := strings.trim_space(string(stdout_minimal))

	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, "=== File summary (git diff --stat) === \n")
	strings.write_string(&sb, stat)
	strings.write_string(&sb, "=== Changes (no context lines) === \n")
	strings.write_string(&sb, minimal)
	strings.write_string(&sb, "\n")

	result := strings.to_string(sb)

	if estimate_tokens(result) <= DIFF_BUDGET {
		return result, true
	}

	max_lines := 50
	for max_lines >= 10 {
		truncated_body := truncate_per_file(minimal, max_lines)

		sb2 := strings.builder_make(context.temp_allocator)
		strings.write_string(&sb2, "=== File summary (git diff --stat) === \n")
		strings.write_string(&sb2, stat)
		strings.write_string(&sb2, "=== Changes (truncated to ")
		fmt.sbprintf(&sb2, "%d lines per file) ===\n", max_lines)
		strings.write_string(&sb2, truncated_body)

		candidate := strings.to_string(sb2)

		if estimate_tokens(candidate) <= DIFF_BUDGET {
			return candidate, true
		}
		max_lines /= 2
	}

	fmt.eprintfln(
		"saft: diff too dense even after truncation, try smaller commits or wait for Tier 3",
	)
	return "", false
}

do_commit :: proc(message: string) -> bool {
	state, _, stderr, err := os.process_exec(
		{command = {"/usr/bin/git", "commit", "-m", message}},
		context.temp_allocator,
	)
	if err != nil {
		fmt.eprintfln("saft: failed to run git commit: %v", err)
		return false
	}
	if state.exit_code != 0 {
		fmt.eprintfln("saft: git commit failed: %s", string(stderr))
		return false
	}
	return true
}
