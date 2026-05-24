package main

import "core:bufio"
import "core:fmt"
import "core:os"
import "core:strings"

Choice :: enum {
	Accept,
	Edit,
	Regenerate,
	Cancel,
}

prompt_choice :: proc() -> Choice {
	reader: bufio.Reader
	bufio.reader_init(&reader, os.to_stream(os.stdin))
	defer bufio.reader_destroy(&reader)

	for {
		fmt.print("\n[a]ccept  [e]dit  [r]egenerate  [c]ancel: ")
		line, err := bufio.reader_read_string(&reader, '\n', context.temp_allocator)
		if err != nil {
			// EOF (Ctrl-D) treated as cancel.
			return .Cancel
		}
		line = strings.trim_space(line)
		if len(line) == 0 {continue}
		switch line[0] {
		case 'a', 'A':
			return .Accept
		case 'e', 'E':
			return .Edit
		case 'r', 'R':
			return .Regenerate
		case 'c', 'C':
			return .Cancel
		case:
			fmt.println("strudel: please answer a, e, r, or c")
		}
	}
}

edit_message :: proc(initial: string) -> (string, bool) {
	tmp_path := "/tmp/strudel-COMMIT_EDITMSG"
	write_ok := os.write_entire_file(tmp_path, transmute([]u8)initial)
	if write_ok != nil {
		fmt.eprintfln("strudel: failed to write tempfile for editor")
		return "", false
	}

	defer os.remove(tmp_path)

	editor := os.get_env("EDITOR", context.temp_allocator)
	if editor == "" {
		editor = "/usr/bin/vim"
	}

	state, _, _, err := os.process_exec(
		{command = {editor, tmp_path}, stdin = os.stdin, stdout = os.stdout, stderr = os.stderr},
		context.temp_allocator,
	)

	if err != nil {
		fmt.eprintfln("strudel: failed to launch editor: %v", err)
		return "", false
	}
	if state.exit_code != 0 {
		fmt.eprintfln("strudel: editor exited %d, commit aborted", state.exit_code)
		return "", false
	}

	content, read_ok := os.read_entire_file_from_path(tmp_path, context.temp_allocator)
	if read_ok != nil {
		fmt.eprintln("strudel: failed to re-read tempfile after edit")
		return "", false
	}
	return strings.trim_space(string(content)), true
}
