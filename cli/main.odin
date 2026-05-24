package main

import "core:fmt"
import "core:os"

main :: proc() {
	defer free_all(context.temp_allocator)

	if !in_git_repo() {
		fmt.eprintln("strudel: not in a git repository")
		os.exit(1)
	}

	helper_path, helper_ok := find_helper()
	if !helper_ok {
		fmt.eprintln("strudel: could not find strudel-helper binary")
		fmt.eprintln("        set $STRUDEL_HELPER, or install it next to strudel")
		os.exit(1)
	}

	diff, diff_ok := get_staged_diff()
	if !diff_ok {
		os.exit(1)
	}
	if len(diff) == 0 {
		fmt.eprintln("strudel: nothing staged to commit")
		fmt.eprintln("        use `git add` to stage changes first")
		os.exit(1)
	}

	message: string
	outer: for {
		msg, ok := generate_message(helper_path, diff)
		if !ok {
			os.exit(1)
		}

		fmt.println("\nProposed commit message:")
		fmt.println("------------------------")
		fmt.println(msg)
		fmt.println("------------------------")

		choice := prompt_choice()
		switch choice {
		case .Accept:
			message = msg
			break outer
		case .Edit:
			edited, edit_ok := edit_message(msg)
			if !edit_ok {
				os.exit(1)
			}
			if len(edited) == 0 {
				fmt.eprintln("strudel: empty message after edit, commit aborted")
				os.exit(1)
			}
			message = edited
			break outer
		case .Regenerate:
			continue
		case .Cancel:
			fmt.println("strudel: cancelled, nothing committed")
			os.exit(0)
		}
		break outer
	}

	if !do_commit(message) {
		os.exit(1)
	}
	fmt.println("strudel: committed")
}
