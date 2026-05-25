package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

find_helper :: proc() -> (string, bool) {
	if env := os.get_env("SAFT_HELPER", context.temp_allocator); env != "" {
		if os.exists(env) {
			return env, true
		}
		fmt.eprintfln("saft: $SAFT_HELPER set but file not found: %s", env)
		return "", false
	}

	exe_dir, dir_err := os.get_executable_directory(context.temp_allocator)
	if dir_err != nil {
		fmt.eprintfln("studel: could not locate own executable: %v", dir_err)
		return "", false
	}

	c1, _ := filepath.join({exe_dir, "saft-helper"}, context.temp_allocator)
	c2, _ := filepath.join({exe_dir, "..", "libexec", "saft-helper"}, context.temp_allocator)
	c3, _ := filepath.join(
		{exe_dir, "..", "helper", ".build", "debug", "saft-helper"},
		context.temp_allocator,
	)
	c4, _ := filepath.join(
		{exe_dir, "..", "helper", ".build", "release", "saft-helper"},
		context.temp_allocator,
	)

	candidates := []string{c1, c2, c3, c4}
	for c in candidates {
		if os.exists(c) {
			return c, true
		}
	}
	return "", false
}

generate_message :: proc(helper_path: string, diff: string) -> (string, bool) {
	in_r, in_w, err1 := os.pipe()
	if err1 != nil {
		fmt.eprintfln("saft: failed to create stdin pipe: %v", err1)
		return "", false
	}

	out_r, out_w, err2 := os.pipe()
	if err2 != nil {
		os.close(in_r); os.close(in_w)
		fmt.eprintfln("saft: failed to create stdout pipe: %v", err2)
		return "", false
	}


	err_r, err_w, err3 := os.pipe()
	if err3 != nil {
		os.close(in_r); os.close(in_w)
		os.close(out_r); os.close(out_w)
		fmt.eprintfln("saft: failed to create stderr pipe: %v", err3)
		return "", false
	}

	proc_handle, start_err := os.process_start(
		{command = {helper_path}, stdin = in_r, stdout = out_w, stderr = err_w},
	)

	if start_err != nil {
		os.close(in_r); os.close(in_w)
		os.close(out_r); os.close(out_w)
		os.close(err_r); os.close(err_w)
		fmt.eprintfln("saft: failed to spawn helper: %v", start_err)
		return "", false
	}

	os.close(in_r)
	os.close(out_w)
	os.close(err_w)

	_, write_err := os.write(in_w, transmute([]u8)diff)
	if write_err != nil {
		fmt.eprintfln("saft: failed to wrtie diff to helper: %v", write_err)
		os.close(in_w); os.close(out_r); os.close(err_r)
		return "", false
	}
	os.close(in_w)

	stdout_bytes, read_out_err := os.read_entire_file_from_file(out_r, context.temp_allocator)
	if read_out_err != nil {
		fmt.eprintfln("saft: failed to read helper stdout: %v", read_out_err)
	}
	stderr_bytes, read_err_err := os.read_entire_file_from_file(err_r, context.temp_allocator)
	if read_out_err != nil {
		fmt.eprintfln("saft: failed to read helper stderr: %v", read_err_err)
	}
	os.close(out_r)
	os.close(err_r)

	state, wait_err := os.process_wait(proc_handle)
	if wait_err != nil {
		fmt.eprintfln("saft: failed to wait for helper: %v", wait_err)
		return "", false
	}

	if state.exit_code != 0 {
		fmt.eprintfln(
			"saft: helper failed (exit: %d): %s",
			state.exit_code,
			strings.trim_space(string(stderr_bytes)),
		)
		return "", false
	}

	return strings.trim_space(string(stdout_bytes)), true
}
