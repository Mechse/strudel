package main

import "core:fmt"
import "core:os"

main :: proc() {
	defer free_all(context.temp_allocator)

	if !in_git_repo() {
		fmt.eprintln("saft: not in a git repository")
		os.exit(1)
	}

	helper_path, helper_ok := find_helper()
	if !helper_ok {
		fmt.eprintln("saft: could not find saft-helper binary")
		fmt.eprintln("        set $SAFT_HELPER, or install it next to saft")
		os.exit(1)
	}

	diff, diff_ok := get_staged_diff_tier_1()

	if !diff_ok {
		os.exit(1)
	}
	if len(diff) == 0 {
		fmt.eprintln("saft: nothing staged to commit")
		fmt.eprintln("        use `git add` to stage changes first")
		os.exit(1)
	}

	tokens := estimate_tokens(diff)

	// DEBUG
	// fmt.printfln("Tokens Calculated: %d", tokens)
	// DEBUG END

	switch {
	case tokens <= TIER_1_MAX:
		break
	case tokens <= TIER_2_MAX:
		sp: Spinner
		spinner_start(&sp, "Compressing diff...")
		diff, diff_ok = get_staged_diff_tier_2()
		spinner_stop(&sp)
		break
	case tokens > TIER_2_MAX:
		fmt.printfln("saft: Tier 3 not implemented yet.")
		os.exit(1)
	}

	// DEBUG
	// if tokens > TIER_1_MAX && tokens <= TIER_2_MAX {
	// 	fmt.printfln("Tokens Compressed: %d", estimate_tokens(diff))
	// 	fmt.printfln("%s", diff)
	// }
	// DEBUG END

	message: string
	outer: for {
		sp: Spinner
		spinner_start(&sp, "Generating commit message...")
		msg, ok := generate_message(helper_path, diff)
		spinner_stop(&sp)
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
				fmt.eprintln("saft: empty message after edit, commit aborted")
				os.exit(1)
			}
			message = edited
			break outer
		case .Regenerate:
			continue
		case .Cancel:
			fmt.println("saft: cancelled, nothing committed")
			os.exit(0)
		}
		break outer
	}

	if !do_commit(message) {
		os.exit(1)
	}
	fmt.println("saft: committed")
}
